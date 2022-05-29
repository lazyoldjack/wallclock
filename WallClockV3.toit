// Wall Clock V3
// Copyright 2022 John Ellis. All rights reserved.
// V3 added MQTT storage of the clock face time (where the hands are pointing)


// ESP32 system to drive 100yr old school clock that requires a pulse every 30 seconds.
// Accuracy is maintained by Toit's time being maintained from some timeserver or other.

import gpio
import net.tcp show ServerSocket
import net
import mqtt

import rest_server show RestServer RestRequest RestResponse

coil/gpio.Pin ::= gpio.Pin 12 --output // Pin to drive solenoid MOSFET.

ctime/Time := Time.now // Clock face time.
PULSETIME_MS ::= 10 // Time for pulse to be on in ms.
// The maximum time we are willing to wait to get to an accurate time.
// If the clock is only slightly ahead we are going to stand still until the
// time is correct again.
MAX_STAND_STILL_DURATION ::= Duration --m=5
SEC30 ::= Duration --s=30
SEC60 ::= Duration --s=60
SEC0 ::= Duration --s=0

CLIENT_ID ::= "WallClock"
HOST ::= "192.168.1.19" // Or could use lesjalons.uk.to if clock was on different network but will be lower via internet.
PORT ::= 1883
TOPIC ::= "/mqtt/wallclock"


// Either cft, clock face time form or thy, thank you.
// Static HTML defined here.
HTML_CFT := """<html>
    <head>
        <title>Clock Face Time</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="icon" href="data:,">
        <style>
            html{font-family: Helvetica; display:inline-block; margin: 0px auto; text-align: center;}
            h1{color: #0F3376; padding: 2vh;}p{font-size: 1.5rem;}
            table{color: #0F0F76; padding: 2vh;}p{font-size: 1.5rem; align:center;}
            table.center {
                margin-left:auto;
                margin-right:auto;
            }
            .button{display: inline-block; background-color: #e7bd3b; border: none; border-radius: 4px; color: white; padding: 16px 40px; text-decoration: none; font-size: 30px; margin: 2px; cursor: pointer;}
            .button2{background-color: #4286f4;}
        </style>
    </head>
    <body>
        <h1>Clock Face Time</h1>
        <p>Please enter the time showing on the clock face:</p>
        <form  action="/thy" method="post">
        <table class="center">
        <tr><td>Hours</td><td>Mins</td><td>Secs</td><td/></tr>
        <tr><td>
        <select id="hh" name="hh" width="2">
            $((List 12: "<option value=\"$it\">$(%02d it)</option>").join "\n")
        </select>
        </td>
        <td>
        <select id="mi" name="mi"  width="2">
            $((List 60: "<option value=\"$it\">$(%02d it)</option>").join "\n")
        </select>
        </td>
        <td>
        <select id="ss" name="ss" width="2">
            <option value="0">00</option>
            <option value="30">30</option>
        </select>
        <input type="hidden" id="dummy" name="dummy" value="999"/>
        </td>
        <td>
        <input type="submit" value="Submit" style="button">
        </td>
        </form>
    </body>
</html>"""

html_thy t/Time -> string:
  return """
    <html>
        <head>
            <title>Clock Face Time</title>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <link rel="icon" href="data:,">
            <style>
                html{font-family: Helvetica; display:inline-block; margin: 0px auto; text-align: center;}
                h1{color: #0F3376; padding: 2vh;}p{font-size: 1.5rem;}
                table{color: #0F0F76; padding: 2vh;}p{font-size: 1.5rem; align:center;}
                table.center {
                    margin-left:auto;
                    margin-right:auto;
                }
                .button{display: inline-block; background-color: #e7bd3b; border: none; border-radius: 4px; color: white; padding: 16px 40px; text-decoration: none; font-size: 30px; margin: 2px; cursor: pointer;}
                .button2{background-color: #4286f4;}
            </style>
        </head>
        <body>
            <h1>Clock set to:</h1>
            <p>
            $(%02d t.local.h):$(%02d t.local.m):$(%02d t.local.s)
            </p>
            <p><a href="http://www.google.com"><button class="button button2">Finished</button></a><p>
        </body>
    </html>"""


//////////////////////////////
pulse pclient/mqtt.Client:
  coil.set 1
  sleep --ms=PULSETIME_MS
  coil.set 0
  ctime = ctime + SEC30
  // Publish the latest clock face time to be retained in case of power outage.
  pclient.publish TOPIC ctime.local.stringify.to_byte_array --qos=1 --retain=true
  //print "published $ctime.local"
  //wdt.feed() //feed watchdog timer if required


////////////////////////////////////////
set_ctime val:
  thing := []
  print "==== Setting Clock time..."
  print val

  mp := {:} // Time map.

  val.do: | item |
    thing = item.split "="
    mp[thing[0]] = int.parse thing[1]

  // The click only shows 12 hours. We can decide whether it's currently AM or PM.
  now := Time.now.local
  am := Time.local now.year now.month now.day mp["hh"] mp["mi"] mp["ss"]
  pm := Time.local now.year now.month now.day (mp["hh"] + 12) mp["mi"] mp["ss"]

  // Note that we don't take daylight savings into account when trying to find the best
  // time.

  // We are willing to let the clock stand still for up to $MAX_STAND_STILL_DURATION seconds.
  // For that the two possible times must be in the future.
  if am < now.time: am += Duration --h=24
  if pm < now.time: pm += Duration --h=24
  if (now.time.to am) < MAX_STAND_STILL_DURATION:
    ctime = am
    return
  if (now.time.to pm) < MAX_STAND_STILL_DURATION:
    ctime = pm
    return

  // We now know that we need to catch up. Make sure both possible times are indeed in the past.
  am -= Duration --h=24
  pm -= Duration --h=24

  if (am.to now.time) < (pm.to now.time):
    ctime = am
  else:
    ctime = pm



/////////////////////// main ///////////////////////////////////////////////////

main :
  print "WallClock starting..."

  // Set up MQTT client for use in pub and sub.
  socket := net.open.tcp_connect HOST PORT
  client := mqtt.Client
      CLIENT_ID
      mqtt.TcpTransport socket

  // Set up sub to get last cft.
  client.subscribe TOPIC --qos=1

  start_ctime/Time := Time.from_string "2000-01-01T12:00:00Z"

  task::
    just_started/bool := true
    client.handle: | topic/string payload/ByteArray |
      if just_started: // Only do this once at startup - may remove this flag once unsub is working.
        just_started = false
        stored_cft := payload.to_string
        print "Sub recvd: Stored cft was $stored_cft"
        start_ctime = Time.from_string stored_cft
        client.unsubscribe TOPIC
      else:
        print "discarding at $Time.now" // Should never see this if unsubscribe works correctly.

      print "end of client.handle task"


  /////////// Set up responses from restserver.
  ss /ServerSocket := net.open.tcp_listen 80

  rest := RestServer (ss)
  //log_system.get_recent_logs 25 // For example return the last 25 logs generated prior to the exception


  rest.get "/cft" :: | req/RestRequest resp/RestResponse |
    resp.http_res.write HTML_CFT

  rest.post "/thy" :: | reqt/RestRequest respt/RestResponse |
    page := html_thy Time.now
    respt.http_res.write page

    set_ctime (reqt.http_req.body.read.to_string.split "&")


  ////// Initialise coil driver to off.
  coil.set 0
  sleep --ms=2_000 // Wait so do not get double pulse if restart is very fast and time to receive subscription.

  /////// Wait for right time for first click.
  while Time.now.local.s !=0 and Time.now.local.s !=30:
    //print Time.now.local.s
    sleep --ms=500

  print "********* Starting @ $Time.now.local because secs = $Time.now.local.s"
  print "start_ctime is $start_ctime"
  if start_ctime.utc.year == 2000: // There was no stored time to pick up via MQTT.
    pulse client
    ctime = Time.now // Kickoff without getting right time.
  else:
    ctime = start_ctime //kickoff with stored cft from MQTT

  ///////// Now pulse if/when required.

  // Whether the wall clock is in a good regime and just ticking along.
  on_time := true
  while true:
    now := Time.now.local
    // Terminate every day at noon for a clean slate.
    if on_time and (now.h == 12 and now.m == 0 and now.s == 5):
      break

    dur := Duration.since ctime
    // Check to prevent restart if time is being adjusted, ie dur is > 60secs or less than 0.
    on_time = SEC0 <= dur <= SEC60

    if dur >= SEC30:
      pulse client

    sleep --ms=480 //was checkWait

  // Exiting for restart.
  // Probably not required, testing... pulse client// will miss this one while exiting so explicitly do it here.
  print "Stopping for clean slate restart"

  exit 0   // Hard exit to kill restserver as well as this program.
