path = require('path')
request = require('../src/request')(
    debug: true
    cacheDir: path.resolve(__dirname, 'tmp')
)

root = 'http://jsonplaceholder.typicode.com';

request "#{root}/posts/1", (err, res, body) ->
    console.log body

request.get "#{root}/posts/1", (err, res, body) ->
    console.log body

