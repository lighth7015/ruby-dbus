#!/usr/bin/env ruby
# Test the main loop
require File.expand_path("../test_helper", __FILE__)
require "test/unit"
require "dbus"

class MainLoopTest < Test::Unit::TestCase
  def setup
    @session_bus = DBus::ASessionBus.new
    svc = @session_bus.service("org.ruby.service")
    @obj = svc.object("/org/ruby/MyInstance")
    @obj.introspect                  # necessary
    @obj.default_iface = "org.ruby.Loop"

    @loop = DBus::Main.new
    @loop << @session_bus
  end

  # Hack the library internals so that there is a delay between
  # sending a DBus call and listening for its reply, so that
  # the bus has a chance to join the server messages and a race is reproducible
  def call_lazily
    class << @session_bus
      alias :wait_for_message_orig :wait_for_message
      def wait_for_message_lazy
        DBus.logger.debug "I am so lazy"
        sleep 1    # Give the server+bus a chance to join the messages
        wait_for_message_orig
      end
      alias :wait_for_message :wait_for_message_lazy
    end

    yield

    # undo
    class << @session_bus
      remove_method :wait_for_message
      remove_method :wait_for_message_lazy
      alias :wait_for_message :wait_for_message_orig
    end
  end

  def test_loop_quit(delay = 1)
    @obj.on_signal "LongTaskEnd" do
      DBus.logger.debug "Telling loop to quit"
      @loop.quit
    end

    call_lazily do
      # The method will sleep the requested amount of seconds
      # (in another thread)  before signalling LongTaskEnd
      @obj.LongTaskBegin delay
    end

    # this thread will make the test fail if @loop.run does not return
    dynamite = Thread.new do
      DBus.logger.debug "Dynamite burning"
      sleep 2
      DBus.logger.debug "Dynamite explodes"
      # We need to raise in the main thread.
      # Simply raising here means the exception is ignored
      # (until dynamite.join which we don't call) or
      # (if abort_on_exception is set) it terminates the whole script.
      Thread.main.raise RuntimeError, "The main loop did not quit in time"
    end

    @loop.run
    DBus.logger.debug "Defusing dynamite"
    # if we get here, defuse the bomb
    dynamite.exit
    # remove signal handler
    @obj.on_signal "LongTaskEnd"
  end

  # https://bugzilla.novell.com/show_bug.cgi?id=537401
  def test_loop_drained_socket
    test_loop_quit 0
  end
end
