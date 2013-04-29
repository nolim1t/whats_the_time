request = require 'request'
mongo = require './mongo.coffee'

# coffee -e 'require("./lib/thetimeis.coffee").updatetzfromfs {foursquareid: "", tzid: ""}, (cb) -> console.log cb'
updatetzfromfs = (info, cb) ->
	if info.foursquareid != undefined and info.tzid != undefined
		mongo.dbhandler (db) ->
			collection = db.collection("users")
			query = {foursquareid: info.foursquareid.toString()}
			collection.find(query).toArray (e,a) ->
				if a.length == 1
					collection.update query, {$set: {tz: info.tzid}}, (err, updated) -> console.log "Updated profile with " + info.tzid
					cb({meta: {code: 200, msg: "Done"}})
				else
					cb({meta: {code: 400, msg: "Invalid user"}})
	else
		cb({meta: {code: 400, msg: "Invalid parameters"}})

# coffee -e 'require("./lib/thetimeis.coffee").gettzfromdb {slug: ""}, (cb) -> console.log cb'
gettzfromdb = (info, cb) ->
	if info.slug != undefined
		mongo.dbhandler (db) ->
			collection = db.collection("users")
			query = {randomslug: info.slug}
			collection.find(query).toArray (e, a) ->
				if a.length == 1
					cb({meta: {code: 200, msg: "OK"}, tzinfo: a[0].tz})
				else
					cb({meta: {code: 400, msg: "Cant find user"}})
	else
		cb({meta: {code: 400, msg: "Invalid parameters"}})

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
				cb({time: b, meta: {code: 200}})
			catch e
				cb({meta: {code: 500, msg: e}})
		else
			cb({meta: {code: r.statusCode}})

# coffee -e 'require("./lib/thetimeis.coffee").tztotime {identifier: "tester", loc: "-33.859972,151.211111"}, (cb) -> console.log cb'
tztotime = (info, cb) ->
	if info.loc != undefined and info.identifier != undefined
		require("./thetimeis.coffee").tz {identifier: info.identifier, loc: info.loc}, (ccb) ->
			if ccb.meta.code == 200
				require(".//thetimeis.coffee").time {tzid: ccb.tzid, ts: Math.round(Date.now() / 1000)}, (ctcb) ->
					cb(ctcb)
			else
				cb({meta: ccb.meta}) 
			
module.exports = {
	tz: mytz,
	time: currenttime,
	tztotime: tztotime,
	updatetzfromfs: updatetzfromfs,
	gettzfromdb: gettzfromdb
}