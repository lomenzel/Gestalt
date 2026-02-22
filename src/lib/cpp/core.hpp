#pragma once

#include <functional>
#include <map>
#include <stdexcept>
#include <string>
#include <utility>
#include <variant>
#include <vector>
#include <unordered_map>
#include <atomic>

class GestaltCore {
public:
  struct Value {
    using List = std::vector<Value>;
    using Set = std::map<std::string, Value>;
    using Func = std::function<Value(Value)>;

    enum class Type { Null, Bool, Int, Float, String, List, Set, Lambda };

    Type type;
    std::variant<std::monostate, bool, long long, double, std::string, List, Set, Func> value;

    Value() : type(Type::Null), value(std::monostate{}) {}

    static Value null() { return Value(Type::Null, std::monostate{}); }
    static Value fromBool(bool v) { return Value(Type::Bool, v); }
    static Value fromInt(long long v) { return Value(Type::Int, v); }
    static Value fromFloat(double v) { return Value(Type::Float, v); }
    static Value fromString(std::string v) { return Value(Type::String, std::move(v)); }
    static Value fromList(List v) { return Value(Type::List, std::move(v)); }
    static Value fromSet(Set v) { return Value(Type::Set, std::move(v)); }
    static Value lambda(Func v) { return Value(Type::Lambda, std::move(v)); }

    bool isInt() const { return type == Type::Int; }
    bool isFloat() const { return type == Type::Float; }
    bool isBool() const { return type == Type::Bool; }
    bool isString() const { return type == Type::String; }
    bool isNumber() const { return type == Type::Int || type == Type::Float; }

    long long asInt() const {
      if (type == Type::Int) return std::get<long long>(value);
      throw std::runtime_error("GestaltCore::Value: expected int");
    }

    double asFloat() const {
      if (type == Type::Float) return std::get<double>(value);
      if (type == Type::Int) return static_cast<double>(std::get<long long>(value));
      throw std::runtime_error("GestaltCore::Value: expected float");
    }

    bool asBool() const {
      if (type == Type::Bool) return std::get<bool>(value);
      throw std::runtime_error("GestaltCore::Value: expected bool");
    }

    const std::string &asString() const {
      if (type == Type::String) return std::get<std::string>(value);
      throw std::runtime_error("GestaltCore::Value: expected string");
    }

    Value call(Value arg) const {
      if (type != Type::Lambda) throw std::runtime_error("GestaltCore::Value: expected lambda");
      return std::get<Func>(value)(std::move(arg));
    }

    Value operator()(Value arg) const { return call(std::move(arg)); }

  private:
    template <typename T>
    Value(Type t, T v) : type(t), value(std::move(v)) {}
  };
  using Observer = std::function<void(const Value&)>;

  explicit GestaltCore();


  Value dispatch(const std::string& actionName, const Value& params = Value());

  void reset();

  Value getState() const;
  Value viewState() const;
  Value getActionParams() const { return actionParams_; }
  Value getMeta() const { return meta_;}


  size_t subscribe(Observer obs);
  void unsubscribe(size_t id);

private:
  Value state_;
  Value actions_;
  Value view_;
  Value initialState_;
  Value actionParams_;
  Value meta_;

  size_t nextObserverId_ = 1;
  std::unordered_map<size_t, Observer> observers_;
};
