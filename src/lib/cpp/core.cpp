#include "core.hpp"

using Value = GestaltCore::Value;

GestaltCore::GestaltCore(std::function<void(Value)> effectCallback)
  : state_(%initialState%),
    actions_(%actions%),
    view_(%view%),
    initialState_(%initialState%),
    actionParams_(%actionParams%),
    initialEffect_(%initialEffect%),
    meta_(%meta%),
    effectCallback_(std::move(effectCallback))
{
  effectCallback_(initialEffect_);
}

void GestaltCore::dispatch(const std::string& actionName, const Value& params) {
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
  } catch (const std::exception &e) {
    throw std::runtime_error(std::string("action threw an exception: ") + e.what());
  } catch (...) {
    throw std::runtime_error("action threw an unknown exception");
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

  auto effIt = rset.find("effect");
  if (effIt != rset.end() && effectCallback_) effectCallback_(effIt->second);
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

void GestaltCore::runUnitTests(Value tests) {
  if (tests.type != Value::Type::List) throw std::runtime_error("runUnitTests: expected a list of tests");

  struct Result { std::string description; bool pass; };
  std::vector<Result> results;

  for (const Value t : std::get<Value::List>(tests.value)) {
    if (t.type != Value::Type::Set) throw std::runtime_error("runUnitTests: each test must be a set/object");

    std::string description = t["description"].asString();
    Value func = t["func"];
    Value params = t["params"];
    Value pass = t["pass"];

    bool passed = false;

    if (func.type != Value::Type::Lambda) throw std::runtime_error("runUnitTests: 'func' must be a lambda");
    Value funcResult = func(params);
    if (pass.type != Value::Type::Lambda) throw std::runtime_error("runUnitTests: 'pass' must be a lambda");
    Value passResult = pass(funcResult);
    if (!passResult.isBool()) throw std::runtime_error("runUnitTests: 'pass' must return a boolean");
    passed = passResult.asBool();


    results.push_back({description, passed});
  }

  size_t numberPassed = 0;
  for (const auto &r : results) if (r.pass) ++numberPassed;
  size_t numberFailed = results.size() - numberPassed;

  if (numberFailed > 0) {
    std::cout << "Failed Tests:" << std::endl;
    for (const auto &r : results) if (!r.pass) std::cout << "- " << r.description << std::endl;
  }

  std::cout << "Unit Tests:\npassed: " << numberPassed << ",\nfailed: " << numberFailed << std::endl;

  if (numberFailed > 0) std::exit(1);
}
