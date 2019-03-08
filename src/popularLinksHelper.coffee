util					= require "util"
http					= require "http"
https					= require "https"
urlHelper				= require "url"

Seq							= require "seq"
_							= require "underscore"

parseForLinks			= require "all-the-links"
request					= require "request"

logger = console

# Returns a an array mirroring link structure
#	[lang: languaged page ,url: languagePageUrl, popularLinks: [popularLink1, popularLink2, ..]]
#

fetchPopularLinks = (lg, rootUrl, callback)->
	logger = lg or console
	Seq().seq ->
		#logger.debug "will get HTML #{rootUrl}"
		getHtml rootUrl, this
	.seq (rootHtml)->
		#logger.debug "will get LINKS #{rootUrl}"
		getLinks rootUrl, rootHtml, this
	.seq (links)->
		#console.log "Found links", links
		links = _.chain(links).uniq().filter( (l)-> l.indexOf("popular") > 0 ).value()
		this(null, links)
	.flatten()
	.parEach (pageUrl, i)->
		#logger.debug "will get HTML #{pageUrl}"
		getHtml pageUrl, this.into(pageUrl)
	.parEach (pageUrl)->
		#logger.debug "will get LINKS #{pageUrl}"
		html = this.vars[pageUrl]
		langRe = /<html\slang=["']?([\w-]*)["']?>/
		matches = html.match langRe
		key = "NOLANG"
		if matches?.length > 1
			key = matches[1]
		if this.vars.pageUrlMap is undefined
			this.vars.pageUrlMap = {}
		this.vars.pageUrlMap[key] = pageUrl
		getLinks pageUrl, html, this.into(key)		
	.seq ->
		#logger.debug util.format("will format & return %j", this.vars)
		linksMap = _.pick this.vars, (value, key, object) -> return _.isArray value
		links = []
		for lang, popularLinks of linksMap
			externalLinks = _.filter popularLinks, (link) -> link.indexOf("swishly.com") is -1
			url = this.vars.pageUrlMap[lang]
			links.push lang: lang, url: url, popularLinks: externalLinks
		callback null, links
	.catch (err)->
		callback err

getLinks = (urlStr, html, fn)->
	Seq().seq ->
		parseForLinks html, this
	.seq (links)->
		for i, link of _.filter(links, (l)-> _.isString(l))
			if not link.startsWith "http"
				links[i] = urlHelper.resolve urlStr, link
		fn?(null, links)
	.catch (err)->
		fn?(err)


getHtml = (urlStr, fn)->
	options = urlHelper.parse(urlStr)
	options.url = urlStr
	options.headers = 
		"User-Agent": "Mozilla/5.0 (iPad; CPU OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B143 Safari/601.1"
		"Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
		#"Accept-Encoding":"gzip, deflate, sdch"
		"Accept-Language":"en-US,en;q=0.8,fr;q=0.6"
		"Connection":"keep-alive"
		"Host":options.host

	request options, (error, response, body) ->
		if error
			fn?(error)
		else
			contentType = response?.headers["content-type"]
			if contentType is undefined
				fn?(new Error("Response for #{options.url} is missing content-type header"))
			else if contentType.split(";")[0] isnt "text/html"
				fn?(new Error("Response for #{options.url}: expected content-type: 'text/html', got '#{response?.headers["content-type"]}' instead"))
			else
				fn?(null, body)


httpStatusForLink = (urlStr, fn)->
	#console.log "Will process for  #{urlStr}"
	try 
		if urlStr.startsWith "https"
			req = https.get(urlStr)
		else
			req = http.get(urlStr)
		
		result = url: urlStr, status: "ok"
		req.on "error", (response)->
			result.status = "alert"
			result.text = "No response for #{urlStr}"
			fn?(null, result)
		req.on "response", (response)->
			#console.log "HTTP response for #{urlStr} is '#{response.statusCode}'"
			if response.statusCode >= 200 and response.statusCode < 300
				result.text = "ok"
			else if response.statusCode >= 300 and response.statusCode < 400  and location = response.headers["location"]
				result.text = "Redirect '#{response.statusCode}' to #{location}"
				result.status = "alert"
			else
				server = response.headers.server or "unknown"
				if server.match(/(?:cloudflare|Cloudproxy)/i) and response.statusCode in [403, 503]
					result.text = "ok"
				else
					result.status = "alert"
					result.text = "Unexpected HTTP response code '#{response.statusCode}', server '#{server}'"
			fn?(null, result)
	catch err
		console.log "httpStatusForLink error"
		fn?(err)

httpStatusForLinks = (links, fn)->
	Seq(links).flatten()
	.seqMap (link)->
		console.log "Will process for  #{link}"
		httpStatusForLink link, this
	.unflatten()
	.seq (results)->
		fn?(null, results)
	.catch (error)->
		fn?(error)




videoStatsForLink = (link, fn)->
	hostname = urlHelper.parse(link).hostname
	days = 2
	urlStr = "https://bend.swishly.com/reports/webtv/recent-site-activity/#{days}/#{hostname}"
	req = https.get(urlStr)
	result = url: link, status: "ok"

	request urlStr, (error, response, body)->
		if error
			result.status = "error"
			result.error = new Error("No response for #{urlStr}")
			fn?(null, result)
		else if response.statusCode < 200 or response.statusCode > 400
			result.status = "error"
			result.error = new Error("http error #{response.statusCode} for #{urlStr}")
			fn?(null, result)
		else
			try 
				rows = JSON.parse body
				if not _.isArray rows
					throw (new Error("Expected an array from #{urlStr}"))
				if rows.length is 0
					result.status = "alert"
					result.text = "No Activity"
				else
					info = rows[0]
					if info.playedVideoCount == 0 or info.playbackErrorCount > (info.spottedVideoCount/2)
						result.status = "alert"
					else if info.playedVideoCount < (info.spottedVideoCount/2) or info.playbackErrorCount > (info.spottedVideoCount/4)
						result.status = "warning"
					result.text = "Videos Spotted: #{info.spottedVideoCount}, Videos Played: #{info.playedVideoCount}, Playback Errors: #{info.playbackErrorCount}"
					result.info = info
			catch error
				result.error = error
			finally
				fn?(null, result)

videoStatsForLinks = (links, fn)->
	#console.log "Will process for  #{links}"
	Seq(links).flatten()
	.parMap (link)->
		videoStatsForLink link, this
	.unflatten()
	.seq (results)->
		#console.log "OK results #{results.length}"
		fn?(null, results)
	.catch (err)->
		log.error "ERROR in videoStatsForLinks()", err
		fn?(err)

module.exports = 
	fetchPopularLinks: fetchPopularLinks
	videoStatsForLinks: videoStatsForLinks
	httpStatusForLinks: httpStatusForLinks
	getLinks: getLinks