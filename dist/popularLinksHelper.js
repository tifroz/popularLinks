// Generated by CoffeeScript 2.2.3
var Seq, _, fetchPopularLinks, getHtml, getLinks, http, httpStatusForLink, httpStatusForLinks, https, logger, parseForLinks, request, urlHelper, util, videoStatsForLink, videoStatsForLinks;

util = require("util");

http = require("http");

https = require("https");

urlHelper = require("url");

Seq = require("seq");

_ = require("underscore");

parseForLinks = require("all-the-links");

request = require("request");

logger = console;

// Returns a an array mirroring link structure
//	[lang: languaged page ,url: languagePageUrl, popularLinks: [popularLink1, popularLink2, ..]]

fetchPopularLinks = function(lg, rootUrl, callback) {
  logger = lg || console;
  return Seq().seq(function() {
    //logger.debug "will get HTML #{rootUrl}"
    return getHtml(rootUrl, this);
  }).seq(function(rootHtml) {
    //logger.debug "will get LINKS #{rootUrl}"
    return getLinks(rootUrl, rootHtml, this);
  }).seq(function(links) {
    //console.log "Found links", links
    links = _.chain(links).uniq().filter(function(l) {
      return l.indexOf("popular") > 0;
    }).value();
    return this(null, links);
  }).flatten().parEach(function(pageUrl, i) {
    //logger.debug "will get HTML #{pageUrl}"
    return getHtml(pageUrl, this.into(pageUrl));
  }).parEach(function(pageUrl) {
    var html, key, langRe, matches;
    //logger.debug "will get LINKS #{pageUrl}"
    html = this.vars[pageUrl];
    langRe = /<html\slang=["']?([\w-]*)["']?>/;
    matches = html.match(langRe);
    key = "NOLANG";
    if ((matches != null ? matches.length : void 0) > 1) {
      key = matches[1];
    }
    if (this.vars.pageUrlMap === void 0) {
      this.vars.pageUrlMap = {};
    }
    this.vars.pageUrlMap[key] = pageUrl;
    return getLinks(pageUrl, html, this.into(key));
  }).seq(function() {
    var externalLinks, lang, links, linksMap, popularLinks, url;
    //logger.debug util.format("will format & return %j", this.vars)
    linksMap = _.pick(this.vars, function(value, key, object) {
      return _.isArray(value);
    });
    links = [];
    for (lang in linksMap) {
      popularLinks = linksMap[lang];
      externalLinks = _.filter(popularLinks, function(link) {
        return link.indexOf("swishly.com") === -1;
      });
      url = this.vars.pageUrlMap[lang];
      links.push({
        lang: lang,
        url: url,
        popularLinks: externalLinks
      });
    }
    return callback(null, links);
  }).catch(function(err) {
    return callback(err);
  });
};

getLinks = function(urlStr, html, fn) {
  return Seq().seq(function() {
    return parseForLinks(html, this);
  }).seq(function(links) {
    var i, link, ref;
    ref = _.filter(links, function(l) {
      return _.isString(l);
    });
    for (i in ref) {
      link = ref[i];
      if (!link.startsWith("http")) {
        links[i] = urlHelper.resolve(urlStr, link);
      }
    }
    return typeof fn === "function" ? fn(null, links) : void 0;
  }).catch(function(err) {
    return typeof fn === "function" ? fn(err) : void 0;
  });
};

getHtml = function(urlStr, fn) {
  var options;
  options = urlHelper.parse(urlStr);
  options.url = urlStr;
  options.headers = {
    "User-Agent": "Mozilla/5.0 (iPad; CPU OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B143 Safari/601.1",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    //"Accept-Encoding":"gzip, deflate, sdch"
    "Accept-Language": "en-US,en;q=0.8,fr;q=0.6",
    "Connection": "keep-alive",
    "Host": options.host
  };
  return request(options, function(error, response, body) {
    var contentType;
    if (error) {
      return typeof fn === "function" ? fn(error) : void 0;
    } else {
      contentType = response != null ? response.headers["content-type"] : void 0;
      if (contentType === void 0) {
        return typeof fn === "function" ? fn(new Error(`Response for ${options.url} is missing content-type header`)) : void 0;
      } else if (contentType.split(";")[0] !== "text/html") {
        return typeof fn === "function" ? fn(new Error(`Response for ${options.url}: expected content-type: 'text/html', got '${(response != null ? response.headers["content-type"] : void 0)}' instead`)) : void 0;
      } else {
        return typeof fn === "function" ? fn(null, body) : void 0;
      }
    }
  });
};

httpStatusForLink = function(urlStr, fn) {
  var err, req, result;
  try {
    //console.log "Will process for  #{urlStr}"
    if (urlStr.startsWith("https")) {
      req = https.get(urlStr);
    } else {
      req = http.get(urlStr);
    }
    result = {
      url: urlStr,
      status: "ok"
    };
    req.on("error", function(response) {
      result.status = "alert";
      result.text = `No response for ${urlStr}`;
      return typeof fn === "function" ? fn(null, result) : void 0;
    });
    return req.on("response", function(response) {
      var location, ref, server;
      //console.log "HTTP response for #{urlStr} is '#{response.statusCode}'"
      if (response.statusCode >= 200 && response.statusCode < 300) {
        result.text = "ok";
      } else if (response.statusCode >= 300 && response.statusCode < 400 && (location = response.headers["location"])) {
        result.text = `Redirect '${response.statusCode}' to ${location}`;
        result.status = "alert";
      } else {
        server = response.headers.server || "unknown";
        if (server.match(/(?:cloudflare|Cloudproxy)/i) && ((ref = response.statusCode) === 403 || ref === 503)) {
          result.text = "ok";
        } else {
          result.status = "alert";
          result.text = `Unexpected HTTP response code '${response.statusCode}', server '${server}'`;
        }
      }
      return typeof fn === "function" ? fn(null, result) : void 0;
    });
  } catch (error1) {
    err = error1;
    console.log("httpStatusForLink error");
    return typeof fn === "function" ? fn(err) : void 0;
  }
};

httpStatusForLinks = function(links, fn) {
  return Seq(links).flatten().seqMap(function(link) {
    console.log(`Will process for  ${link}`);
    return httpStatusForLink(link, this);
  }).unflatten().seq(function(results) {
    return typeof fn === "function" ? fn(null, results) : void 0;
  }).catch(function(error) {
    return typeof fn === "function" ? fn(error) : void 0;
  });
};

videoStatsForLink = function(link, fn) {
  var days, hostname, req, result, urlStr;
  hostname = urlHelper.parse(link).hostname;
  days = 2;
  urlStr = `https://bend.swishly.com/reports/webtv/recent-site-activity/${days}/${hostname}`;
  req = https.get(urlStr);
  result = {
    url: link,
    status: "ok"
  };
  return request(urlStr, function(error, response, body) {
    var info, rows;
    if (error) {
      result.status = "error";
      result.error = new Error(`No response for ${urlStr}`);
      return typeof fn === "function" ? fn(null, result) : void 0;
    } else if (response.statusCode < 200 || response.statusCode > 400) {
      result.status = "error";
      result.error = new Error(`http error ${response.statusCode} for ${urlStr}`);
      return typeof fn === "function" ? fn(null, result) : void 0;
    } else {
      try {
        rows = JSON.parse(body);
        if (!_.isArray(rows)) {
          throw new Error(`Expected an array from ${urlStr}`);
        }
        if (rows.length === 0) {
          result.status = "alert";
          return result.text = "No Activity";
        } else {
          info = rows[0];
          if (info.playedVideoCount === 0 || info.playbackErrorCount > (info.spottedVideoCount / 2)) {
            result.status = "alert";
          } else if (info.playedVideoCount < (info.spottedVideoCount / 2) || info.playbackErrorCount > (info.spottedVideoCount / 4)) {
            result.status = "warning";
          }
          result.text = `Videos Spotted: ${info.spottedVideoCount}, Videos Played: ${info.playedVideoCount}, Playback Errors: ${info.playbackErrorCount}`;
          return result.info = info;
        }
      } catch (error1) {
        error = error1;
        return result.error = error;
      } finally {
        if (typeof fn === "function") {
          fn(null, result);
        }
      }
    }
  });
};

videoStatsForLinks = function(links, fn) {
  //console.log "Will process for  #{links}"
  return Seq(links).flatten().parMap(function(link) {
    return videoStatsForLink(link, this);
  }).unflatten().seq(function(results) {
    return typeof fn === "function" ? fn(null, results) : void 0;
  }).catch(function(err) {
    log.error("ERROR in videoStatsForLinks()", err);
    return typeof fn === "function" ? fn(err) : void 0;
  });
};

module.exports = {
  fetchPopularLinks: fetchPopularLinks,
  videoStatsForLinks: videoStatsForLinks,
  httpStatusForLinks: httpStatusForLinks,
  getLinks: getLinks
};
