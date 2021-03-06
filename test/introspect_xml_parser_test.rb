#!/usr/bin/env ruby
require File.expand_path("../test_helper", __FILE__)
require "test/unit"
require "dbus"

class IntrospectXMLParserTest < Test::Unit::TestCase
  def test_split_interfaces
    xml = <<EOS
<node>
   <interface name="org.example.Foo">
     <method name="Dwim"/>
   </interface>
   <interface name="org.example.Bar">
     <method name="Drink"/>
   </interface>
   <interface name="org.example.Foo">
     <method name="Smurf"/>
   </interface>
</node>
EOS

    interfaces, _ = DBus::IntrospectXMLParser.new(xml).parse

    foo = interfaces.find {|i| i.name == "org.example.Foo" }
    assert_equal 2, foo.methods.keys.size
  end
end
