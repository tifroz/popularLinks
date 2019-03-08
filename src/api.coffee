Seq							= require "seq"
_							= require "underscore"
helper						= require "./popularLinksHelper.js"
urlParse					= require("url").parse


filteredResults = (level, results)->
	filtered = _.filter results, (r)->
		status = r.status.toLowerCase()
		if level is "warning"
			return status in ["warning", "alert"]
		else if level is "alert"
			return status in ["alert"]
		else
			return true
	return filtered

videoStatsText = (rootUrl, level, callback)->
	Seq().seq ->
		helper.fetchPopularLinks console, rootUrl, this
	.flatten()
	.parEach (languagePage, i)->
		console.log "languagePage #{languagePage}"
		helper.videoStatsForLinks languagePage.popularLinks, this.into(languagePage.url)
	.unflatten()
	.seq (languagePages)->
		message = ""
		pages = _(languagePages).chain().pluck("url").uniq().value()
		console.log pages
		for page in pages
			console.log "ok looking at #{page}"
			flaggedResults = filteredResults level, this.vars[page]
			
			# netcine.us videos are hosted on 3rd party sites, "No Activity" is expected
			flaggedResults = _.filter flaggedResults, (r)->
				hostname = urlParse(r.url).hostname.toLowerCase()
				isNetCine = hostname.endsWith "netcine.us"
				iSNoActivity = r.text.toLowerCase() is "no activity"
				console.log "'#{hostname}' -> '#{r.text}', isNetCine=#{isNetCine}, iSNoActivity=#{iSNoActivity}"
				if isNetCine and iSNoActivity
					console.info "**** removing #{hostname} from results ****"
					return false
				return true

			if flaggedResults.length > 0
				message += "\n\n"
				message += "******************\ Video Results for #{page} ******************\n"
				for r in flaggedResults
					message += "#{r.status}\t#{r.url}\t\t\t\t(#{r.text})\n"
		callback(null, message)
	.catch (err)->
		console.error err.stack
		callback(err)


httpStatusPromise = (rootUrl)->
	promise = new Promise( (resolve, reject)->
		httpStatusReport(rootUrl, (err, results)->
			if err
				reject(err)
			else
				resolve(results)
		)
	)
	return promise

httpStatusReport = (rootUrl, callback)->
	Seq().seq ->
		helper.fetchPopularLinks console, rootUrl, this
	.flatten()
	.parEach (languagePage, i)->
		helper.httpStatusForLinks languagePage.popularLinks, this.into(languagePage.url)
	.unflatten()
	.seq (languagePages)->
		callback null, this.vars
	.catch (err)->
		console.error err.stack
		callback(err)

httpStatusText = (rootUrl, level, callback)->
	Seq().seq ->
		httpStatusReport rootUrl, this
	.seq (jsonReport) ->
		text = ""
		for page, report of jsonReport
			flaggedResults = filteredResults level, report
			if flaggedResults.length > 0
				text += "\n\n"
				text += "******************\ HTTP Results for #{page} ******************\n"
				for r in flaggedResults
					text += "#{r.status}\t#{r.url}\t\t\t\t(#{r.text})\n"
		callback(null, text)
	.catch (err)->
		console.error err.stack
		callback(err)

module.exports = 
	httpStatusText: httpStatusText
	httpStatusPromise: httpStatusPromise
	videoStatsText: videoStatsText