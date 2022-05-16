// Wall Clock V2 
// Copyright 2022 John Ellis. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

// ESP32 system to drive 100yr old school clock that requires a pulse every 30 seconds
// Accuracy is maintained by Toit's time being maintained from some timeserver or other

import gpio 
import net.tcp show ServerSocket 
import net

import rest_server show RestServer RestRequest RestResponse

coil/gpio.Pin := gpio.Pin 12 --output //pin to drive solenoid MOSFET

ctime/Time := Time.now //Clock face time
pulseTime := 10 //time for pulse to be on in ms
checkWait := 1000 - pulseTime //milliseconds wait before checking time. This will be the click rate at its fastest when clock is behind at beginning of summertime// pulsetime will contribute to total wait
sec30 := Duration --s=30
sec60 := Duration --s=60
sec0 := Duration --s=0
dur := Duration --s=0
restart/bool := true

ss /ServerSocket := net.open.tcp_listen 80
mp := {:} //time map
cval := [] //incoming time values to set clock


//either cft, clock face time form or thy, thank you
//static HTML defined here
htmlcft := """<html>
    <head>
        <title>Clock Face TIme</title>
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
            <option value="0">00</option>
            <option value="1">01</option>
            <option value="2">02</option>
            <option value="3">03</option>
            <option value="4">04</option>
            <option value="5">05</option>
            <option value="6">06</option>
            <option value="7">07</option>
            <option value="8">08</option>
            <option value="9">09</option>
            <option value="10">10</option>
            <option value="11">11</option>
        </select>
        </td>
        <td>
        <select id="mi" name="mi"  width="2">
            <option value="0">00</option>
            <option value="1">01</option>
            <option value="2">02</option>
            <option value="3">03</option>
            <option value="4">04</option>
            <option value="5">05</option>
            <option value="6">06</option>
            <option value="7">07</option>
            <option value="8">08</option>
            <option value="9">09</option>
            <option value="10">10</option>
            <option value="11">11</option>
            <option value="12">12</option>
            <option value="13">13</option>
            <option value="14">14</option>
            <option value="15">15</option>
            <option value="16">16</option>
            <option value="17">17</option>
            <option value="18">18</option>
            <option value="19">19</option>
            <option value="20">20</option>
            <option value="21">21</option>
            <option value="22">22</option>
            <option value="23">23</option>
            <option value="24">24</option>
            <option value="25">25</option>
            <option value="26">26</option>
            <option value="27">27</option>
            <option value="28">28</option>
            <option value="29">29</option>
            <option value="30">30</option>
            <option value="31">31</option>
            <option value="32">32</option>
            <option value="33">33</option>
            <option value="34">34</option>
            <option value="35">35</option>
            <option value="36">36</option>
            <option value="37">37</option>
            <option value="38">38</option>
            <option value="39">39</option>
            <option value="40">40</option>
            <option value="41">41</option>
            <option value="42">42</option>
            <option value="43">43</option>
            <option value="44">44</option>
            <option value="45">45</option>
            <option value="46">46</option>
            <option value="47">47</option>
            <option value="48">48</option>
            <option value="49">49</option>
            <option value="50">50</option>
            <option value="51">51</option>
            <option value="52">52</option>
            <option value="53">53</option>
            <option value="54">54</option>
            <option value="55">55</option>
            <option value="56">56</option>
            <option value="57">57</option>
            <option value="58">58</option>
            <option value="59">59</option>
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

htmlthy := """<head>
        <title>Clock Face TIme</title>
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
        <p>"""

/**   Time now inserted here when response is made **/
xx := """</p>
        <p><a href="http://www.google.com"><button class="button button2">Finished</button></a><p>
    </body>
</html>"""


//////////////////////////////
pulse:
    coil.set 1
    sleep 
        --ms=pulseTime
    coil.set 0
    ctime = ctime + sec30
    //wdt.feed()


////////////////////////////////////////
setctime val:
    thing := []
    print "==== Setting Clock time..."
    print val

    val.do: | item |
        thing = item.split "="
        mp[thing[0]] = int.parse thing[1]
    if Time.now.local.h > 11: //12 or after in 24hr clock
        mp["hh"] = mp["hh"] + 12
    ////now set ctime to be these values
    ctime = Time.local Time.now.local.year Time.now.local.month Time.now.local.day mp["hh"] mp["mi"] mp["ss"]
    cval.clear // prevent a second call of this routing by clearing the global variable




/////////////////////// main ///////////////////////////////////////////////////

main :

    print "WallClock starting..."

/////////// set up responses from restserver
     // Whatever this lambda returns is added to the body json of the 500 reply on exception
    rest := RestServer (ss) 
        //log_system.get_recent_logs 25 // For example return the last 25 logs generated prior to the exception


    rest.get "/cft" :: | req/RestRequest resp/RestResponse |
        resp.http_res.write htmlcft

    rest.post "/thy" :: | reqt/RestRequest respt/RestResponse |
        t := Time.now
        page := htmlthy + "$(%02d t.local.h):$(%02d t.local.m):$(%02d t.local.s) " + xx 
        respt.http_res.write page  

        cval = reqt.http_req.body.read.to_string.split "&"

        

////// initialise coil driver to off
    coil.set 0
    sleep --ms=2000 //wait so do not get double pulse if restart is very fast

/////// wait for right time for first click
    while Time.now.local.s !=0 and Time.now.local.s !=30: //wait for optimum time to start
        //print Time.now.local.s
        sleep --ms=500

    print "********* Starting @ $Time.now.local because secs = $Time.now.local.s"
    pulse
    ctime = Time.now //kickoff

///////// now click if/when required, terminate every day at noon for a clean slate
    while not (Time.now.local.h == 12 and Time.now.local.m == 00 and Time.now.local.s == 0 and restart):
        dur = Duration.since ctime
        //print dur
        //check to prevent restart if time is being adjusted, ie dur is > 60secs or less than 0
        if dur > sec60 or dur < sec0:
            restart = false
        else:
            restart = true

        if dur >= sec30:
            //print "pulse: $Time.now.local"
            pulse
        sleep --ms=480 //was checkWait

        //check for clock setting
        if cval.is_empty == false: //values set so use them
            setctime cval
    //exiting for restart        
    pulse // will miss this one while exiting so explicitly do it here
    print "Stopping for clean slate"
    
    exit 0   //hard exit to kill restserver as well as this program
        






