# Resque::Clues

Resque-Clues allows Resque to publish job lifecycle events to some external
store for analysis.  It also allows for decorating jobs stored in Redis with
metadata that will be included with the published events.  When coupled with
tools like Splunk, Logstash/Graphite or Cube, this can be used to:

* Quantify results of balancing efforts, hardware changes, etc...
* See how your background processes perform over time, before and after
releases, etc...
* Break down performance metrics on metadata specific to your business or
  domain.
* Provide searchability for specific jobs entering the queue to aid in
  debugging or support efforts.

Coupled with those tools, it will enable you to create views into your
background processes like the following:

![splunk dashboard](http://i.imgur.com/0sZEw1L.png?1)

## Lifecycle events

Four lifecycle events will be published for each job entering a queue:

1. enqueued
2. dequeued
3. perform_started
4. perform_finished -or- failed

Each will contain the following information (plus anything added to the
metadata via an item preprocessor):

* event_type: Either enqueued, dequeued, perform_started, perform_finished or
  failed.
* event_hash: Unique hash grouping all events associated with a single 
  background job.
* worker_class: The job class that contains the perform logic.
* queue: The queue the job is placed into.
* timestamp: The time the event occurs.
* hostname: The hostname of the machine where the event originates from.
* process: The process on the host machine where the event originates from.
* args: The arguments passed to the perform method.

dequeued events will also include time_in_queue, which is the amount of time
the job spent in the queue. perform_finished and failed events will include
time_to_perform, which is the time it took to perform the job after it was
dequeued.  Failed events will include the exception class, the exception
message and a backtrace. 

## Event Publishers

Event publishers are use to receive event data and publish them in some way.
The following event publishers are currently provided:

```ruby
Resque::Plugins::Clues::StandardOutPublisher
Resque::Plugins::Clues::LogPublisher
Resque::Plugins::Clues::CompositePublisher
Resque::Plugins::Clues::FilterPublisher
```

You can implement your own publishers as long as they implement event handling
methods as follows:

```ruby
def publish(event_type, timestamp, queue, metadata, klass, *args)
  ...
end
```

Where event_type is enqueued, dequeued, perform_started, perform_finished and
failed.

## Event Marshallers

An event marshallers is used to coerce event data into a format suitable for
sending to an event publisher's destination.  This is a proc or lambda with the
following call signature:  

```ruby
lambda do |event_type, timestamp, queue, metadata, worker_class, args|
  # something that returns a string
end
```

By default, clues will use an event_marshaller that will simply marshall this
data to a JSON object in the following format:

```
{
  "event_type":"dequeued",
  "timestamp":"2013-06-04T20:59:58Z",
  "queue":"test_queue",
  "metadata": {
    "event_hash":"0695f49c5e70fc18da91961113e1769a"
    "hostname":"Lances-MacBook-Air.local",
    "process":30731
  },
  "worker_class":"TestWorker",
  "args":[1,2]
}
```

## Item Preprocessors

Immediately before Resque puts job data into a queue, the queue and the payload
hash will be sent to a configurable item_preprocessor proc.  The payload hash
will contain:

* class:  The class of the job to perform.
* args:  The args to pass to its perform method.
* metadata:  The metadata hash that contains the event_hash identifier, the
hostname and the process doing the enqueing.

You can then inject whatever you need into the metadata hash and it will be 
included in the published events.  At PeopleAdmin, we are using this to inject
our customer identifiers so we can look at Resque analytics broken down on a
per-customer basis.

## Installation

Add this line to your application's Gemfile:

    gem 'resque-clues'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install resque-clues

## Usage

Resque-clues requires configuration of the event publishers and an item
preprocessor to be used, and this should occur before any use of Resque.  Here 
is an example configuration:

```ruby
require 'resque'
require 'resque-clues'

publisher = Resque::Plugins::Clues::CompositePublisher.new
publisher << Resque::Plugins::Clues::StandardOutPublisher.new
publisher << Resque::Plugins::Clues::LogPublisher.new("/var/log/resque-clues.log")
Resque::Plugins::Clues.event_publisher = publisher

Resque::Plugins::Clues.item_preprocessor = proc do |queue, item| 
  ...
end
```

If used in a Rails application, this will need to be executed in an initalizer.
If used outside of a Rails application, this will need to be executed in the Rakefile
to ensure that both the application enqueuing jobs and the workers are configured. 
This can be done by creating an initializer and requiring it in your Rakefile 
after you have required both resque and resque-clues. After this, you should see 
events published as appropriate for your configured event publisher.


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
