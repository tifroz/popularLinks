Seq							= require "seq"
_							= require "underscore"
email						= require "emailjs"
program						= require "commander"
util						= require "util"

helper						= require "./popularLinksHelper.js"

emailServer = email.server.connect
	user: 'monitor@swishly.com'
	password: 'n3xtg3ncab'
	host: 'smtp.gmail.com'
	ssl: true

Seq().seq ->
	emailServer.send
		text: "*report*"
		from: "webmonitor@swishly.com"
		to: "hugo@swishly.com"
		subject: "web monitor report TEST",
		this

.seq (msg)->
	console.log util.format("Message from the email server: %j", msg)
.catch (err)->
	console.error "Error #{err}"