require 'js-yaml'
express = require 'express'
assert = require('chai').assert
request = require 'request'
http = require 'http'
swagger = require '../'
pathUtils = require 'path'
_  = require 'underscore'

describe 'API generation tests', ->
  server = null
  host = 'localhost'
  port = 8090
  root = '/api'

  it 'should fail if no Express application is provided', ->
    assert.throws ->
      swagger.generator()
    , /^No Express application provided/

  it 'should fail if plain object is provided', ->
    assert.throws ->
      swagger.generator {}
    , /^No Express application provided/

  it 'should fail if no descriptor provided', ->
    assert.throws ->
      swagger.generator express()
    , /^Provided root descriptor is not an object/

  it 'should fail if no api or controller provided for a resource', ->
    assert.throws ->
      swagger.generator express(), {}, [{}]
    , /Resource must contain 'api' and 'controller' attributes/

  it 'should fail on missing resource path', ->
    assert.throws ->
      swagger.generator express(), {}, [
        api: {}
        controller: require './fixtures/sourceCrud'
      ]
    , /Resource without path/

  it 'should fail on missing api path', ->
    assert.throws ->
      swagger.generator express(), {}, [
        api:
          resourcePath: '/test'
          apis: [{}]
        ,
        controller: require './fixtures/sourceCrud'
      ]
    , /api without path/

  it 'should fail on unsupported operation in descriptor', ->
    assert.throws ->
      swagger.generator express(), {}, [
        api:
          resourcePath: '/test'
          apis: [
            path: '/'
            operations: [
              httpMethod: 'TOTO'
              nickname: 'doNotExist'
            ]
          ]
        controller: require './fixtures/sourceCrud'
      ]
    , /operation TOTO is not supported/

  it 'should fail on unknown nickname in descriptor', ->
    assert.throws ->
      swagger.generator express(), {}, [
        api:
          resourcePath: '/test'
          apis: [
            path: '/'
            operations: [
              httpMethod: 'GET'
              nickname: 'doNotExist'
            ]
          ]
        controller: require './fixtures/sourceCrud'
      ]
    , /nickname doNotExist cannot be found in controller/

  it 'should fail on missing nickname in descriptor', ->
    assert.throws ->
      swagger.generator express(), {}, [
        api:
          resourcePath: '/test'
          apis: [
            path: '/'
            operations: [
              httpMethod: 'GET'
            ]
          ]
        controller: require './fixtures/sourceCrud'
      ]
    , /does not specify a nickname/

  it 'should fail on duplicate parameters in descriptor', ->
    assert.throws ->
      swagger.generator express(), {}, [
        api:
          resourcePath: '/test'
          apis: [
            path: '/'
            operations: [
              httpMethod: 'GET'
              nickname: 'stat'
              parameters: [
                name: 'p1'
              ,
                name: 'p2'
              ,
                name: 'p3'
              ,
                name: 'p1'
              ,
                name: 'p4'
              ,
                name: 'p3'
              ]
            ]
          ]
        controller: require './fixtures/sourceCrud'
      ]
    , /has duplicates parameters: p1,p3/

  it 'should fail on parameter (not body) without name', ->
    assert.throws ->
      swagger.generator express(), {}, [
        api:
          resourcePath: '/test'
          apis: [
            path: '/'
            operations: [
              httpMethod: 'GET'
              nickname: 'stat'
              parameters: [
                paramType: 'query'
              ]
            ]
          ]
        controller: require './fixtures/sourceCrud'
      ]
    , /parameter with no name/

  it 'should fail on parameter without paramType', ->
    assert.throws ->
      swagger.generator express(), {}, [
        api:
          resourcePath: '/test'
          apis: [
            path: '/'
            operations: [
              httpMethod: 'GET'
              nickname: 'stat'
              parameters: [
                name: 'p1'
              ]
            ]
          ]
        controller: require './fixtures/sourceCrud'
      ]
    , /parameter p1 has no type/

  it 'should fail on unknown type parameter', ->
    assert.throws ->
      swagger.generator express(), {}, [
        api:
          resourcePath: '/test'
          apis: [
            path: '/'
            operations: [
              httpMethod: 'GET'
              nickname: 'stat'
              parameters: [
                name: 'p1'
                paramType: 'unkown'
              ]
            ]
          ]
        controller: require './fixtures/sourceCrud'
      ]
    , /parameter p1 type unkown is not supported/

  it 'should fail on optionnal path parameter', ->
    assert.throws ->
      swagger.generator express(), {}, [
        api:
          resourcePath: '/test'
          apis: [
            path: '/{p1}'
            operations: [
              httpMethod: 'GET'
              nickname: 'stat'
              parameters: [
                name: 'p1'
                paramType: 'path'
                required: false
              ]
            ]
          ]
        controller: require './fixtures/sourceCrud'
      ]
    , /path parameter p1 cannot be optionnal/

  it 'should fail on path parameter with multiple values', ->
    assert.throws ->
      swagger.generator express(), {}, [
        api:
          resourcePath: '/test'
          apis: [
            path: '/{p1}'
            operations: [
              httpMethod: 'GET'
              nickname: 'stat'
              parameters: [
                name: 'p1'
                paramType: 'path'
                multipleAllowed: true
              ]
            ]
          ]
        controller: require './fixtures/sourceCrud'
      ]
    , /path parameter p1 cannot allow multiple values/

  it 'should fail on path parameter disclosure between path and parameter array', ->
    assert.throws ->
      swagger.generator express(), {}, [
        api:
          resourcePath: '/test'
          apis: [
            path: '/{p1}/{p2}/{p3}'
            operations: [
              httpMethod: 'GET'
              nickname: 'stat'
              parameters: [
                name: 'p1'
                paramType: 'path'
              ]
            ]
          ]
        controller: require './fixtures/sourceCrud'
      ]
    , /declares 3 parameters in its path, and 1 in its parameters array/

  it 'should fail on path parameter name disclosure between path and parameter array', ->
    assert.throws ->
      swagger.generator express(), {}, [
        api:
          resourcePath: '/test'
          apis: [
            path: '/{p1}/{p2}'
            operations: [
              httpMethod: 'GET'
              nickname: 'stat'
              parameters: [
                name: 'p1'
                paramType: 'path'
              ,
                name: 'p3'
                paramType: 'path'
              ]
            ]
          ]
        controller: require './fixtures/sourceCrud'
      ]
    , /declares parameter p2 in its path, but not in its parameters array/

  it 'should fail on two anonymous body parameters', ->
    assert.throws ->
      swagger.generator express(), {}, [
        api:
          resourcePath: '/test'
          apis: [
            path: '/test'
            operations: [
              httpMethod: 'POST'
              nickname: 'stat'
              parameters: [
                paramType: 'body'
              ,
                paramType: 'body'
              ]
            ]
          ]
        controller: require './fixtures/sourceCrud'
      ]
    , /has more than one anonymous body parameter/

  it 'should fail on body parameters for other than put and post', ->
    assert.throws ->
      swagger.generator express(), {}, [
        api:
          resourcePath: '/test'
          apis: [
            path: '/test'
            operations: [
              httpMethod: 'DELETE'
              nickname: 'stat'
              parameters: [
                paramType: 'body'
              ]
            ]
          ]
        controller: require './fixtures/sourceCrud'
      ]
    , /operation DELETE does not allowed body parameters/

  describe 'given a configured server with complex models', ->
    app = null

    # given a started server
    before (done) ->
      app = express()
      app.use(express.cookieParser())
        .use(express.methodOverride())
        .use(express.bodyParser())
        .use(swagger.generator(app, 
          apiVersion: '1.0',
          basePath: root
        , [
          api: require './fixtures/complexApi.yml'
          controller: passed: (req, res) -> res.json status: 'passed'
        ]))
        # use validator also because it manipulates models
        .use(swagger.validator(app))
      server = http.createServer app
      server.listen port, host, done

    after (done) ->
      server.close()
      done()

    it 'should reference models be untouched', (done) ->
      # when requesting the API description details
      request.get
        url: 'http://'+host+':'+port+'/api-docs.json/example'
        json: true
      , (err, res, body) ->
        return done err if err?
        # then a json file is returned
        assert.equal res.statusCode, 200
        assert.deepEqual body,
          apiVersion: '1.0'
          basePath: '/api'
          resourcePath: '/example'
          apis: [
            path: '/example'
            operations: [
              httpMethod: 'POST'
              nickname: 'passed'
              parameters: [
                dataType: 'User'
                paramType: 'body'
                required: true
              ]
            ]
          ],
          models: 
            Address:
              id: 'Address'
              properties:
                zipcode:
                  type: 'long'
                street:
                  type: 'string'
                city:
                  type: 'string'

            User:
              id: 'User'
              properties:
                id:
                  type: 'int'
                  required: true
                name:
                  type: 'string'
                addresses:
                  type: 'array'
                  items: 
                    $ref: 'Address'
        done()

  describe 'given a properly configured and started server', ->
    app = null

    # given a started server
    before (done) ->
      app = express()
      # configured to use swagger generator
      try
        app.use(express.cookieParser())
          .use(express.methodOverride())
          .use(express.bodyParser())
          .use(swagger.generator(app, 
            apiVersion: '1.0',
            basePath: root
          , [
            api: require './fixtures/sourceApi.yml'
            controller: require './fixtures/sourceCrud'
          ,
            api: require './fixtures/streamApi.yml'
            controller: require './fixtures/sourceCrud'
          ]))
          # use validator also because it manipulates models
          .use(swagger.validator(app))
      catch err
        return done err.stack

      server = http.createServer app
      server.listen port, host, done

    after (done) ->
      server.close()
      done()

    it 'should generated API be available', (done) ->
      # when using the generated APIs
      request.post
        url: 'http://'+host+':'+port+'/source'
        json: true
        body:
          name: 'source 1'
      , (err, res, body) ->
        return done err if err?
        # then the API is working as expected
        assert.equal res.statusCode, 200, 'post source API not available'
        assert.isNotNull body.id
        assert.equal body.name, 'source 1'
        source = body
        request.get
          url: 'http://'+host+':'+port+'/source'
          json: true
        , (err, res, body) ->
          return done err if err?
          # then the API is working as expected
          assert.equal res.statusCode, 200, 'get source list API not available'
          assert.deepEqual body, {size:1, total:1, from:0, hits:[source]}
          source.desc = 'hou yeah'
          request.put
            url: 'http://'+host+':'+port+'/source/'+source.id
            json: true
            body: source
          , (err, res, body) ->
            return done err if err?
            # then the API is working as expected
            assert.equal res.statusCode, 200, 'put source API not available'
            assert.deepEqual body, source
            request.get
              url: 'http://'+host+':'+port+'/source/'+source.id
              json: true
            , (err, res, body) ->
              return done err if err?
              # then the API is working as expected
              assert.equal res.statusCode, 200, 'get source API not available'
              assert.deepEqual body, source
              assert.equal body.desc, 'hou yeah'
              request.del
                url: 'http://'+host+':'+port+'/source/'+source.id
                json: true
              , (err, res, body) ->
                return done err if err?
                # then the API is working as expected
                assert.equal res.statusCode, 204, 'delete source API not available'
                request.get
                  url: 'http://'+host+':'+port+'/source'
                  json: true
                , (err, res, body) ->
                  return done err if err?
                  # then the API is working as expected
                  assert.equal res.statusCode, 200
                  assert.deepEqual body, {size:0, from:0, total:0, hits:[]}
                  done()

    it 'should API description be available', (done) ->
      # when requesting the API description
      request.get
        url: 'http://'+host+':'+port+'/api-docs.json'
        json: true
      , (err, res, body) ->
        return done err if err?
        # then a json file is returned
        assert.equal res.statusCode, 200
        assert.deepEqual body,
          apiVersion: '1.0',
          basePath: '/api',
          apis: [
            path:"/api-docs.json/source"
          ,
            path:"/api-docs.json/stream"
          ]
          models: {}

        # when requesting the API description details
        request.get
          url: 'http://'+host+':'+port+'/api-docs.json/source'
          json: true
        , (err, res, body) ->
          return done err if err?
          # then a json file is returned
          assert.equal res.statusCode, 200
          assert.deepEqual body,
            apiVersion: '1.0'
            basePath: '/api'
            resourcePath: '/source'
            apis: [
              path: '/source'
              operations: [
                httpMethod: 'GET'
                nickname: 'list'
              ,
                httpMethod: 'POST'
                nickname: 'create'
              ]
            ,
              path: '/source/{id}'
              operations: [
                httpMethod: 'GET'
                nickname: 'getById'
              ,
                httpMethod: 'PUT'
                nickname: 'update'
              ,
                httpMethod: 'DELETE'
                nickname: 'remove'
              ]
            ]
          done()