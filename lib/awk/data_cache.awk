# data_cache_get_many(file, idx, mode, request, result)
#   file    - file name
#   idx     - value of first field to match (e.g. "2025-11-24")
#   mode    - "num" or "key"
#   request - input array: request[i]=n, n is either a field number or a key
#   result  - output array: result[fieldnum] or result[key] is the value

BEGIN {
	srand()
}

function data_cache_get_many(file, idx, mode, request, result,
                                line, f, i, j, n, key, val) {

    # clear result
	delete result

    # read file and find the matching line
    while ((getline line < file) > 0) {
        split(line, f, ",")
        if (f[1] != idx)
            continue

        if (mode == "num") {
            # request[i] are field numbers
            for (i in request) {
                n = request[i] + 0
                if (n >= 1 && n in f)
                    result[n] = f[n]
            }
        } else if (mode == "key") {
            # request[i] are keys like "DD", "RU"
            for (i in request) {
                key = request[i]
                val = ""
                # search fields for KEY:VALUE
                for (j = 2; j in f; j++) {
                    if (index(f[j], key ":") == 1) {
                        val = substr(f[j], length(key) + 2)
                        break
                    }
                }
                result[key] = val
            }
        }

        break   # stop after the first matching idx line
    }
    close(file)
}

# data_cache_set(file, idx, kv, fv)
#   file - CSV file path
#   idx  - value of first field to match
#   kv   - array: kv["DD"]="123", kv["RU"]="456", ...
#   fv   - array: fv[2]="newF2", fv[4]="newF4", ...

function data_cache_set(file, idx, kv, fv,
                           tmp, line, f, i, j,
                           key, val, found_idx, had_key) {
    datacache_lock(file)

    tmp = get_temp_file_name() ".tmp"
    found_idx = 0
	modified = 0

    # rewrite file into tmp
    while ((getline line < file) > 0) {
        split(line, f, ",")

        if (f[1] == idx) {
            found_idx = 1

            # 1) update numeric fields (fv)
            for (i in fv) {
                if (i in f)
                    f[i] = fv[i]
            }

            # 2) update or append key:value pairs (kv)
            for (key in kv) {
                val = kv[key]
                had_key = 0

                # look for existing KEY:VALUE field
                for (j = 2; j in f; j++) {
                    if (index(f[j], key ":") == 1) {
                        f[j] = key ":" val
                        had_key = 1
                        break
                    }
                }

                # if missing, append KEY:VALUE at end
                if (!had_key) {
                    # find next free numeric index in f[]
                    j = 1
                    while (j in f) j++
                    f[j] = key ":" val
                }
            }

            # rebuild line from f[]
            line = f[1]
            for (i = 2; i in f; i++)
                line = line OFS f[i]
        }
		
        print line >> tmp
		modified = 1
        close(tmp)
    }
    close(file)

    # if idx was not found, append a new line
    if (!found_idx) {
		g[0] = ""
		delete g
        # build base line: idx plus any numeric fields (fv)
        # start with just idx
        line = idx

        # apply numeric fields to a temp array g[]
        # ensure at least field 1 is idx
        g[1] = idx
        for (i in fv) {
            g[i] = fv[i]
		}

        # now append key:value pairs
        for (key in kv) {
            val = kv[key]
            # find next free position
            j = 1
            while (j in g) j++
            g[j] = key ":" val
        }

        # rebuild full line from g[]
        line = g[1]
        for (i = 2; i in g; i++)
            line = line OFS g[i]

		#print line
        print line >> tmp
        modified = 1
        close(tmp)
    }

    # replace original file
	if (modified)
        system("mv \"" tmp "\" \"" file "\"")

    datacache_unlock(file)
}

function data_cache_delete_key(file, idx, key,
                               tmp, line, f, i, j, n) {
    datacache_lock(file)

    tmp = get_temp_file_name() ".tmp"
	modified = 0

    while ((getline line < file) > 0) {
        split(line, f, ",")

        if (f[1] == idx) {
            # rebuild line without the key
            n = 1
			g[0] = ""
			delete g
            # keep index as first field
            g[n] = f[1]
            n++

            for (i = 2; i in f; i++) {
                if (index(f[i], key ":") == 1) {
                    # skip this KEY:VALUE field
                    continue
                }
                g[n] = f[i]
                n++
            }

            # rebuild line from g[]
            line = g[1]
            for (i = 2; i <= n - 1; i++)
                line = line OFS g[i]
        }

        print line >> tmp
		modified = 1
		close(tmp)
    }

    close(file)
	
    if (modified)
        system("mv \"" tmp "\" \"" file "\"")

    datacache_unlock(file)
}

function data_cache_delete_record(file, idx,
                                  tmp, line, f) {
    datacache_lock(file)

    tmp = get_temp_file_name() ".tmp"

	modified = 0
    while ((getline line < file) > 0) {
        split(line, f, ",")
        if (f[1] == idx)
            continue    # skip this record entirely
        print line >> tmp
		modified = 1
    }
    close(file)
	close(tmp)
	if (modified)
        system("mv \"" tmp "\" \"" file "\"")

    datacache_unlock(file)
}

function get_temp_file_name() {
	return int(rand() * 1000000)
}

# Acquire an exclusive lock for a given data file.
# Busy-waits until the lock is available.
function datacache_lock(file, lock, cmd, rc) {
    lock = file ".lock"

    # Simple spinlock with small sleep.
    while (1) {
        # Use set -C (noclobber) style: create only if not exists.
        cmd = "sh -c 'set -C; : >\"" lock "\"' 2>/dev/null"
        rc = system(cmd)
        if (rc == 0) {
            # Successfully created lock file; we own the lock.
            break
        }
        # Someone else holds the lock; wait a bit and retry.
        system("sleep 0.05")
    }
}

# Release the lock.
function datacache_unlock(file, lock) {
    lock = file ".lock"
    # Best-effort removal.
    system("rm -f \"" lock "\"")
}

