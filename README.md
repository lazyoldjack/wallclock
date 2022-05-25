# wallclock
ESP32 to run 100yr old school wall clock using Toit

This old clock requires a current pulse to operate the solenoid that advances the clock by 30 seconds. 
All the clocks in the school were the same, wired in series and connected to the master clock in the headmaster's office. In this way, all the clocks told the same time, which was important for the synchronisation of lessons. There was no reliable source of precise time available everywhere as there is today.

The ESP32 is connected to the Internet via Wi-Fi and Toit ensures that it magically knows the correct local time.

After startup, the user connects to an HTML form on the clock [IP Address]/cft and tells the program what the time is currently on the clock face. The program then advances the hands, once per second, (or waits if that is appropriate) until the time on the clock face matches actual local time. A variable keeps track of what the clock face time is.

At any time, if the clock face time is behind local time, a pulse is issued to advance the hands. If the clock face time is in advance of local time, then no pulse is issued. In this way, daylight savings are also handled with 2 minutes of pulses (one per second) in the spring and an hour's pause in the fall.

I have not included the pulse delivery circuit because if you manage to obtain a clock such as this, your current requirements are likely to be different but the circuit is very simple. I use a MOSFET driver board, readily available online, a suitable resistor and a 5v supply that is slightly isolated from the main 5v by virtue of a low value resistor charging a 16V capacitor that can supply the current spike, which in my case is only 1ms long. Ensure that it can recharge in one second, to cater for the initial time adjustment and the daylight saving catchup in the spring! Don't forget the flyback diode across the solenoid to protect your MOSFET and to minimise electrical interference generated.

Version 3 uses MQTT to store the clock face time each time the hands are advanced (every 30 secs) so that on powerup, the system can retrieve the stored value and adjust itself without the need for human interaction. I could simply store the clock face time in the memory but that would wear out the ESP32 memory in a couple of years plus the risk of corruption if power failed during write, so that's not an option. Left V2 available for anyone not having access to an MQTT broker.
