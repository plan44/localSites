# LocalSites - local bonjour websites menu

## About

With Safari 11, Apple removed Bonjour bookmarks without warning
(at least without warning in a way I heard, no idea if they announced it somewhere).

As I am developing networked devices that all announce their Web-UI via Bonjour
(in fact, avahi, those devices are LEDE based Linux thingies), Bonjour bookmarks were an essential part of my workflow,
to quickly access units by name in my ever changing zoo of devices.

So I took the opportunity to create my very first app in Swift. Fortunately, I could follow a [really very great tutorial for writing a status bar app in Swift](http://footle.org/WeatherBar/) that explained all the non-obvious details precisely. Of course, I had to add my own bonjour code instead of the weather service code, but that was all.

The result is LocalSites, a small status bar app which simply lists all `_http._tcp` type services in the `local` domain, and opens them in the default browser when selected.

## License

The LocalSites app source code is MIT licensed. 