# LocalSites - local bonjour websites menu

## About

With Safari 11, Apple removed Bonjour bookmarks without warning
(at least without warning in a way I heard, no idea if they announced it somewhere).

As I am developing networked devices that all announce their Web-UI via Bonjour
(in fact, avahi, those devices are LEDE based Linux thingies), Bonjour bookmarks were an essential part of my workflow,
to quickly access units by name in my ever changing zoo of devices.

So I took the opportunity to create my very first app in Swift. Fortunately, I could follow a [really very great tutorial for writing a status bar app in Swift](http://footle.org/WeatherBar/) that explained all the non-obvious details precisely. Of course, I had to add my own bonjour code instead of the weather service code, but that was all.

The result is LocalSites, a small status bar app which simply lists all `_http._tcp` type services in the `local` domain, and opens them in ~~the default~~ a browser of you choice (modifier keys, see *About...* box) when selected.

## History

- **1.0** first version
- **1.1** added options to choose different browsers by holding down modifier keys (option, ctrl, shift) before opening the menu. With no modifier keys, sites still open in the system's default browser.
- **1.2** made run on 10.11 El Capitan (just set 10.11 as deployment target in XCode project), added preference to show a monochrome menu icon instead of the blue one.

## License

The LocalSites app source code is MIT licensed. 
