require "./support"

# Apps override these hooks from another assembly; Alice only makes a method virtual when it is
# abstract or overridden locally, so every hook must be virtual here.

def hook_virtual?(t : System.Type, name : String) : Bool
  m = t.GetMethod(name)
  !m.nil? && m.not_nil!.IsVirtual && !m.not_nil!.IsFinal
end

def test_live_view_hooks_are_overridable
  t = BunnyLive::PubSub.new.GetType().Assembly.GetType("BunnyLive+LiveView").not_nil!
  for name in ["template", "mount", "handle_event", "handle_info"]
    assert hook_virtual?(t, name), "LiveView.#{name} must be virtual"
  end
end

def test_channel_hooks_are_overridable
  t = BunnyLive::PubSub.new.GetType().Assembly.GetType("BunnyLive+Channel").not_nil!
  for name in ["join", "handle_in", "terminate", "join_response"]
    assert hook_virtual?(t, name), "Channel.#{name} must be virtual"
  end
end
