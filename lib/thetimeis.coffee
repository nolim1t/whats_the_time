request = require 'request'
mongo = require './mongo.coffee'

# coffee -e 'require("./lib/thetimeis.coffee").tz {identifier: "tester", loc: "-33.859972,151.211111"}, (cb) -> console.log cb'
mytz = (info, cb) ->
	ts = Math.round(Date.now() / 1000)
	expiryts = ts + (process.env.LOCATIONEXPIRY || 86400)
	# Introduce some randomness into location	
	loc = (parseFloat(info.loc.split(",")[0]) + 0.01).toString() + "," + (parseFloat(info.loc.split(",")[1]) + 0.01).toString()
	url = "https://maps.googleapis.com/maps/api/timezone/json?location=" + encodeURIComponent(loc) + "&timestamp=" + encodeURIComponent(ts) + "&sensor=false"
	mongo.dbhandler (db) ->
		collection = db.collection('lasttz')
		collection.ensureIndex({expiry: 1}, {expireAfterSeconds: 60})
		collection.find({identifier: info.identifier}).toArray (c_err, c_arr) ->
			if not c_err
				if c_arr.length == 1
					cb({meta: {code: 200, from: "db"}, tzid: c_arr[0].tzid})
				else
					request {uri: url, method: "GET"}, (e,r,b) ->
						if not e and r.statusCode == 200
							try
								collection.insert({
									tzid: JSON.parse(b).timeZoneId,
									identifier: info.identifier,
									expiry: expiry: new Date(expiryts * 1000)
								})							
								cb({tzid: JSON.parse(b).timeZoneId, meta: {code: 200, from: "remote"}})
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