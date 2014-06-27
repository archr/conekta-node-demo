logger = require 'morgan'
bodyParser = require 'body-parser'
express = require 'express'
conekta = require 'conekta'
request = require 'superagent'
server = express()


#Logs y parser
server.use logger("dev")
server.use bodyParser.urlencoded
  extended: true


#Se configuran las vistas
server.set 'views', "#{process.cwd()}/views"
server.set 'view engine', "jade"
server.set 'view options',
    pretty: true

#Vista de inicio
server.get '/', (req, res) ->
  res.render 'index'


#Vista con el resultado de la transacción
server.get '/result', (req, res) ->
  res.render 'result'


#Se realiza el cargo a la tarjeta
server.post '/', (req, res) ->
  # Parametros
  charge =
    amount: 51000
    currency: "MXN"
    description: "Pizza Delivery"
    reference_id: "orden_de_id_interno"
    card: req.body.conektaTokenId

  # Callback
  end = (err, response) ->
    if err
      console.log err
      return res.send 500, err
    if response.statusCode isnt 200
      console.log err
      return res.send 500, response.error
    console.log response.body
    return res.redirect '/result'

  # Petición
  request
    .post('https://key_KdghGSQQqYzLPd5h@api.conekta.io/charges')
    .set('Accept', 'application/vnd.conekta-v0.3.0+json')
    .set('Content-type', 'application/json')
    .send(charge)
    .end(end)


#Se inicia el server
server.listen 3000, ->
  console.log "Server corriendo en el puerto 3000"