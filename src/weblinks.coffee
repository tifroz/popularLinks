Seq							= require "seq"
_							= require "underscore"
email						= require "emailjs"
program						= require "commander"
api 						= require "./api"

emailServer = email.server.connect
	user: 'monitor@swishly.com'
	password: 'n3xtg3ncab'
	host: 'smtp.gmail.com'
	ssl: true


program
  .version('0.0.1')
  .option('-a, --appversion [value]', 'App version matching the the landing page, e.g. 1.6.2','1.8.17')
  .option('-r, --reports [value]', 'Comma-separated list of reports to run, e.g http,video','http,video')
  .option('-l, --level [value]', 'Verbosity from "all" (all), "warning" to "alert"','all')
  .option('-d, --debug', 'Print to console instead of sending an email')
  .parse(process.argv);

console.log "requested reports: #{program.reports}"
requestedReports = program.reports.split ","

rootUrl = "https://webtv.swishly.com/iwebtv/app/home-v#{program.appversion}/dist/intro.html"

Seq(requestedReports)
.parEach (report) ->
	if report is "http"
		api.httpStatusText rootUrl, program.level, this.into("http")
	else if report is "video"
		api.videoStatsText rootUrl, program.level, this.into("video")
	else
		console.error "ERROR Request Report '#{report}' not regognized"
		this()
.seq ->
	report = ""
	if this.vars.http
		report  += "HTTP REPORT\n\n"
		report  += "\n\n#{this.vars.http}\n\n"
	if this.vars.video
		report  += "VIDEO REPORT\n\n"
		report  += "\n\n#{this.vars.video}\n\n"
	
	if program.debug or report.length is 0
		reportTxt = report or "(empty, nothing to report)"
		console.log "ok printing report:\n#{reportTxt}"
	else
		console.log "ok sending report over email"
		emailServer.send
			text: report
			from: "webmonitor@swishly.com"
			to: "hugo@swishly.com"
			subject: "web monitor report (v#{program.appversion}, #{program.reports})",
			this

.seq (msg)->
	console.log "Message from the email server: #{msg}"

.catch (err)->
	console.error err.stack
	if not program.debug
		emailServer.send
				text: "Encountered an unexpected error, unable to complete the report\n\n#{err.stack}"
				from: "webmonitor@swishly.com"
				to: "hugo@swishly.com"
				subject: "report run failed (v#{program.appversion}, requested reports: #{program.reports})"

