request = require 'request'

# coffee -e 'require("./lib/thetimeis.coffee").tz {loc: "-33.859972,151.211111"}, (cb) -> console.log cb'
mytz = (info, cb) ->
	ts = Math.round(Date.now() / 1000)
	loc = info.loc
	url = "https://maps.googleapis.com/maps/api/timezone/json?location=" + encodeURIComponent(loc) + "&timestamp=" + encodeURIComponent(ts) + "&sensor=false"
	request {uri: url, method: "GET"}, (e,r,b) ->
		if not e and r.statusCode == 200
			try
				cb({tzid: JSON.parse(b).timeZoneId, meta: {code: 200}})
			catch e
				cb({meta: {code: 500, msg: e}})
		else
			cb({meta: {code: r.statusCode}})

# coffee -e 'require("./lib/thetimeis.coffee").time {tzid: "Australia/Sydney", ts: Math.round(Date.now() / 1000)}, (cb) -> console.log cb'	
currenttime = (info, cb) ->
	ts = info.ts
	tzid = info.tzid
	url = 'http://timestamp-app.herokuapp.com/gettime?ts=' + encodeURIComponent(ts) + '&tz=' + encodeURIComponent(tzid);
	request {uri: url, method: "GET"}, (e,r,b) ->
		if not e and r.statusCode == 200
			try
				cb({time: b, meta: 200})
			catch e
				cb({meta: {code: 500, msg: e}})
		else
			cb({meta: {code: r.statusCode}})

module.exports = {
	tz: mytz,
	time: currenttime
}