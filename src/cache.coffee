fs = require 'fs'
path = require 'path'

clean = (s) ->
    # Remove invalid characters and clean edges
    s = s.replace(/[\.:\-\?\!%@\/\s]/g, '_')
    s = s[1..] while not /^[A-Za-z0-9]/.test(s)
    s = s[0..s.length - 2] while not /[A-Za-z0-9]$/.test(s)
    return s

hashCode = (s) ->
    # http://stackoverflow.com/questions/7616461/generate-a-hash-from-string-in-javascript-jquery
    return 0 if s.length == 0
    h = 0
    for i in [0..s.length - 1]
        h = ((h << 5) - h) + s.charCodeAt(i)
        h = h | 0
    return h

hash = (req) ->
    { method, url, json } = req
    method = method.toLowerCase()
    params = if not method or method is 'get' then req.qs else req.body
    throw 'Unknown params' if params and typeof params isnt 'object'

    ret = url

    # Remove https://, http://, and www.
    ret = ret[5..] if /^https/.test(ret)
    ret = ret[4..] if /^http/.test(ret)
    ret = ret[1..] while not /^[A-Za-z0-9]/.test(ret)
    ret = ret[4..] if /^www\./.test(ret)

    # Add params
    if params
        paramStr = ''
        for k, v of params
            continue if not k
            continue if not v
            k = clean(k)[0..29]
            v = clean(String(v))[0..29]
            paramStr += '__' if paramStr
            paramStr += "#{k}_#{v}"
        ret += '.' + paramStr

    # Assume we're lucky enough not to have a collision with our n < 100 websites
    ret = 'entry-' + hashCode(ret) + '-' + method
    ret += '-json' if json
    
    return path.join(cache.dir, ret)
    
get = (s, cb) ->
    fs.readFile s, 'utf-8', (err, ret) ->
        return cb err if err
        cb null, JSON.parse(ret)

put = (s, v, cb) ->
    console.log "put: #{s}"
    fs.writeFile s, JSON.stringify(v), 'utf-8', cb

cache =
    dir: null
    
    get: (req, cb) ->
        return cb null if not cache.dir
        entry = hash req
        fs.exists entry, (exists) ->
            if exists
                console.log "DEBUG: cache hit: #{entry}"
                get entry, (err, data) ->
                    return cb null if err
                    cb data
            else
                cb null

    put: (req, result, cb) ->
        return cb 'No directory' if not cache.dir
        entry = hash req
        put entry, result, cb

module.exports = cache
