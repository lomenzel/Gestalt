#include "core.hpp"

GestaltCore::GestaltCore()
  : state_(%initialState%),
    actions_(%actions%),
    view_(%view%),
    initialState_(%initialState%),
    actionParams_(%actionParams%),
    meta_(%meta%)
{}

Value GestaltCore::dispatch(const std::string& actionName, const Value& params) {
  // Lookup action in the dynamic `actions_` set
  if (actions_.type != Value::Type::Set) throw std::runtime_error("no actions available");
  auto &set = std::get<Value::Set>(actions_.value);
  auto it = set.find(actionName);
  if (it == set.end()) throw std::runtime_error("Unknown action: " + actionName);

  const Value &action = it->second;
  if (action.type != Value::Type::Lambda) throw std::runtime_error("Action is not callable");

  // Params must be a set (object in JS). Treat null/default as empty set.
  Value paramsObj = params;
  if (paramsObj.type == Value::Type::Null) paramsObj = Value::fromSet(Value::Set{});
  if (paramsObj.type != Value::Type::Set) throw std::runtime_error("Params must be a set/object");

  // Validate params against actionParams_ if available
  if (actionParams_.type == Value::Type::Set) {
    auto &apSet = std::get<Value::Set>(actionParams_.value);
    auto apIt = apSet.find(actionName);
    if (apIt != apSet.end()) {
      const Value &expectedList = apIt->second;
      if (expectedList.type != Value::Type::List) throw std::runtime_error("actionParams entry must be a list");
      std::unordered_map<std::string,bool> expected;
      for (auto &v : std::get<Value::List>(expectedList.value)) {
        if (!v.isString()) throw std::runtime_error("actionParams list must contain strings");
        expected[v.asString()] = true;
      }

      // received keys
      auto &recv = std::get<Value::Set>(paramsObj.value);
      for (auto &kv : recv) {
        if (!expected.count(kv.first)) throw std::runtime_error(std::string("Unexpected parameter: ") + kv.first);
      }
      for (auto &e : expected) {
        if (!recv.count(e.first)) throw std::runtime_error(std::string("Missing parameter: ") + e.first);
      }
    }
  }

  // Build call argument: { state, params }
  Value::Set callArgs;
  callArgs.emplace("state", state_);
  callArgs.emplace("params", paramsObj);
  Value callArg = Value::fromSet(std::move(callArgs));

  // Call action; expect a set { state: <newState>, effect: <effect?> }
  Value result;
  try {
    result = action(callArg);
  } catch (...) {
    throw std::runtime_error("action threw an exception");
  }

  if (result.type != Value::Type::Set) throw std::runtime_error("action must return a set with at least 'state'");
  auto &rset = std::get<Value::Set>(result.value);
  auto stIt = rset.find("state");
  if (stIt == rset.end()) throw std::runtime_error("action result missing 'state'");

  // Update state
  state_ = stIt->second;

  // Notify observers
  for (auto &kv : observers_) {
    try { kv.second(state_); } catch (...) {}
  }

  // Return effect if present
  auto effIt = rset.find("effect");
  if (effIt != rset.end()) return effIt->second;
  return Value::null();
}

GestaltCore::Value GestaltCore::getState() const {
  return state_;
}

GestaltCore::Value GestaltCore::viewState() const {
  if (view_.type == Value::Type::Lambda) return view_(state_);
  return Value::null();
}

size_t GestaltCore::subscribe(Observer obs) {
  const size_t id = nextObserverId_++;
  observers_.emplace(id, std::move(obs));
  return id;
}

void GestaltCore::unsubscribe(size_t id) {
  observers_.erase(id);
}

void GestaltCore::reset() {
  state_ = initialState_;
}
