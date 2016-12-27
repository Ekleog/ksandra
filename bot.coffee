irc     = require "irc"
request = require "request"

chan   = "#shotgun"
server = "irc.rezosup.org"
interv = 60
canada = true
if canada
    nick = "KsandraCa"
    url  = "https://ws.ovh.ca/dedicated/r2/ws.dispatcher/getAvailability2"
    nameof = (code) =>
        return switch code
            when "142cask8" then "KS-5B"
            when "142cask5" then "KS-5A"
            when "142cask4" then "KS-4"
            when "142cask3" then "KS-3"
            when "142cask2" then "KS-2"
            when "142cask9" then "KS-1"
            else "untracked"
else
    nick = "Ksandra"
    url  = "https://ws.ovh.com/dedicated/r2/ws.dispatcher/getAvailability2"
    nameof = (code) =>
        return switch code
            when "160sk32" then "KS-3C"
            when "161sk2" then "KS-2E"
            when "160sk2" then "KS-2A"
            when "160sk1" then "KS-1"
            else "untracked"



formatDate = (date) ->
    normalisedDate = new Date(date - (date.getTimezoneOffset() * 60 * 1000))
    normalisedDate.toISOString().replace /\..+$|[^\d]/g, ''

log = (msg) ->
    console.log formatDate(new Date()) + ": " + msg

available = (callback) =>
     request url, (error, response, body) =>
         log "Request: error=" + JSON.stringify(error) + ", response=" + (response == undefined ? undefined : JSON.stringify(response).substr(0, 30) + "...") + ", body=" + (body == undefined ? undefined : JSON.stringify(body).substr(0, 20) + "...")
         ret = JSON.parse(body).answer.availability
         res = []
         for serv in ret
             name = nameof serv.reference
             if name != "untracked" and (serv.metaZones.some (el, i, a) => el.availability != "unknown" and el.availability != "unavailable")
                 res.push name
         log " `-> " + JSON.stringify(res)
         callback(res)

last_avail = []
next_message = (callback) =>
    available (avail) =>
        new_ones = (s for s in avail when s not in last_avail)
        rem_ones = (s for s in last_avail when s not in avail)
        last_avail = avail
        msg = ""
        if new_ones.length
            msg += "AVAILABLE: " + JSON.stringify(new_ones) + "\n"
        if rem_ones.length
            msg += "SHOTGUNNED: " + JSON.stringify(rem_ones) + "\n"
        callback(msg)

bot = new irc.Client server, nick, {
    channels: [chan],
    autoConnect: false,
    autoRejoin: true,
    stripColors: true,
    debug: true,
    showErrors: true
}

bot.addListener "error", (message) =>
    log "ERROR: ", message

bot.connect () =>
    bot.join chan, () =>
        setInterval(
            (
                () =>
                    next_message (msg) =>
                        if msg != ""
                            bot.say chan, msg
            ),
            interv * 1000
        )
