urllib = require 'url'
request = require 'request'
cache = require './cache'

ENABLE_DEBUG = true

METHODS =
    get: 'GET'
    put: 'PUT'
    patch: 'PATCH'
    post: 'POST'
    head: 'HEAD'
    del: 'DELETE'

module.exports = (defaultOpts = {}) ->    
    debug = false
    disableCache = false
    cacheBlacklist = null
    cacheWhitelist = null
    transformRequest = null

    if defaultOpts.disableCache
        # In case a user is using this module purely for transforming requests
        disableCache = true
        delete defaultOpts.disableCache
    else
        throw "No cache directory provided" if not defaultOpts.cacheDir
        cache.dir = defaultOpts.cacheDir
        delete defaultOpts.cacheDir
    
    if ENABLE_DEBUG or defaultOpts.debug
        debug = true
        delete defaultOpts.debug

    if defaultOpts.cacheBlacklist
        cacheBlacklist = defaultOpts.cacheBlacklist
        delete defaultOpts.cacheBlacklist

    if defaultOpts.cacheWhitelist
        cacheWhitelist = defaultOpts.cacheWhitelist
        delete defaultOpts.cacheWhitelist

    if defaultOpts.transformRequest
        transformRequest = defaultOpts.transformRequest
        delete defaultOpts.transformRequest

    defaultOpts.method = 'GET' if not defaultOpts.method

    normalizeArgs = ->
        url = null
        opts = null
        cb = null

        for arg, i in Array.prototype.slice.call(arguments)
            switch typeof arg
                when 'string'
                    throw 'Unexpected string' if url
                    url = arg
                    break
                when 'object'
                    throw 'Unexpected list' if arg.push and arg.shift
                    url = arg.url if arg.url
                    opts = Object.assign {}, arg, defaultOpts
                    break
                when 'function'
                    throw 'Unexpected function' if cb
                    cb = arg
                else
                    break
            break if url and opts and cb

        throw 'Invalid request' if not url

        opts = Object.assign(opts or {}, defaultOpts)
        opts.url = url

        opts = transformRequest(opts) if transformRequest

        return [opts, cb]

    wrapped = ->
        [opts, cb] = normalizeArgs.apply null, arguments

        # Don't use cache if no callback, because the caller is either doing the request for
        # a. side-effects on the server side
        # b. to listen on the request object's emitted events to get the data, which we cannot replicate at this time
        if not disableCache and cb
            if (not cacheWhitelist or url in cacheWhitelist) and (not cacheBlacklist or url not in cacheBlacklist)
                # Find in cache or cache by wrapping callback
                cache.get opts, (response) ->
                    # TODO: check expiry from the added timestamp?
                    if response
                        console.log "DEBUG: Found in request cache: #{JSON.stringify(opts, null, 2)}" if debug
                        cb null, response, response.body
                        return
                    else
                        console.log "DEBUG: Not in request cache!"
                        cb = do (wrappedCb = cb) -> (err, response, body) ->
                            cbArgs = Array.prototype.slice.call arguments
                            if not err
                                response.cacheTime = Date.now()
                                cache.put opts, response, (err) ->
                                    wrappedCb.apply null, cbArgs
                            else
                                wrappedCb.apply null, cbArgs
                        console.log "DEBUG: Not found, sending request: #{JSON.stringify(opts, null, 2)}" if debug
                        request opts, cb
                return
                
            else
                console.log "DEBUG: Skipping cache for the next request due to whitelist/blacklist.." if debug
                return request opts, cb
        else
            console.log "DEBUG: Disabled cache, sending request: #{JSON.stringify(opts, null, 2)}" if debug
            return request opts, cb

    for fn, method of METHODS
        wrapped[fn] = do (method) ->
            return ->
                [opts, cb] = normalizeArgs.apply null, arguments
                opts.method = method
                wrapped opts, cb

    return wrapped
