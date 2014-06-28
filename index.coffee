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

# Peticion a la API REST de conekta
conekta = (endpoint, params, callback) ->
  console.log "#{endpoint} params:", params
  request
  .post("https://key_KdghGSQQqYzLPd5h@api.conekta.io#{endpoint}")
  .set('Accept', 'application/vnd.conekta-v0.3.0+json')
  .set('Content-type', 'application/json')
  .send(params)
  .end (err, res) ->
    if err
      console.log "#{endpoint} error:", console.log err
      return callback(err)

    if res.statusCode isnt 200
      console.log "#{endpoint} error:", res.error
      return callback(new Error(res.error))

    console.log "#{endpoint} response:", res.body
    callback(null, res.body)

# Variables generales

CLIENT = null
PLAN = null

_charge =
  amount: 51000
  currency: "MXN"
  description: "Pizza Delivery"
  reference_id: "orden_de_id_interno"

_client =
  name: "James Howlett"
  email: "james.howlett@forces.gov"
  phone: "55-5555-5555"

# Para crear el plan debe de tener un id aleatorio
planId = [1,2,3,4,5].sort(-> .5 - Math.random()).join('')
_plan =
  id:"plan-#{planId}"
  name:"Gold Plan"
  amount:10000
  currency:"MXN"
  interval:"month"
  frequency:1
  trial_period_days:15
  expiry_count:12

# Clona objetos
clone = (obj) ->
  temp = {}
  for key, value of obj
    temp[key] = value
  temp


# Realiza un pago
middlewareCharge = (req, res, next) ->
  charge = clone(_charge)
  charge.card = req.body.conektaTokenId
  conekta '/charges', charge
  , (err, data) ->
    if err
      return res.send(500, err)
    req.charge = data
    next()


# Crea un nuevo cliente
middlewareNewClient = (req, res, next) ->
  if CLIENT
    console.log 'client', CLIENT
    return next()

  client = clone(_client)
  client.cards =
    if req.body.conektaTokenId
      [req.body.conektaTokenId]
    else
      ['tok_test_visa_4242']

  conekta '/customers', client,
  (err, data) ->
    if err
      return res.send(500, err)

    CLIENT = data
    next()


# Crea un plan
middlewareNewPlan = (req, res, next) ->
  if PLAN
    console.log 'plan', PLAN
    return next()

  conekta '/plans', _plan
  , (err, data) ->
    if err
      return res.send(500, err)
    PLAN = data
    next()


#Vista de inicio
server.get '/', (req, res) ->
  res.render 'list'


#Vista con el resultado de la transacción
server.get '/result', (req, res) ->
  res.render 'result'


# pagos con tarjeta
server.route('/pagos-con-tarjeta')
.get (req, res) ->
  res.render 'index',
    action: '/pagos-con-tarjeta'
.post middlewareCharge, (req, res) ->
  res.redirect '/result'


# pagos bajo demanda
server.route('/bajo-demanda')
.get (req, res) ->
  res.render 'index',
    action: '/bajo-demanda'
.post middlewareNewClient, (req, res) ->
  charge = clone(_charge)
  charge.card = CLIENT.id

  # Se espera un 1 minuto para realizar un pago
  setTimeout ->
    conekta '/charges', charge, (err, data) ->
  , 60000

  res.redirect '/result'


# suscripciones
# -Se crea un plan sino existe
# -Se crea un cliente sino existe
# -Se realiza la suscripcion
server.route('/suscripciones')
.get (req, res) ->
  res.render 'index',
    action: '/suscripciones'
.post middlewareNewPlan, middlewareNewClient, (req, res) ->
  conekta "/customers/#{CLIENT.id}/subscription", {plan: _plan.id}
  , (err, data) ->
    if err
      res.send 500, err
    res.redirect '/result'




#Se inicia el server
server.listen 3000, ->
  console.log "Server corriendo en el puerto 3000"