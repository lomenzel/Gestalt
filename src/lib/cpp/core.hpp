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
#include <nlohmann/json.hpp>
#include <iostream>

/*
  json handling is AI generated. if something breaks, check there first.
*/

class GestaltCore {
public:
  struct Value {
    using List = std::vector<Value>;
    using Set = std::unordered_map<std::string, Value>;
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

    std::string typeName() const {
      switch (type) {
        case Type::Null: return "null";
        case Type::Bool: return "bool";
        case Type::Int: return "int";
        case Type::Float: return "float";
        case Type::String: return "string";
        case Type::List: return "list";
        case Type::Set: return "set";
        case Type::Lambda: return "lambda";
      }
      throw std::runtime_error("gestalt_primop_typeOf: unknown type");
    }

    Value call(Value arg) const {
      if (type != Type::Lambda) throw std::runtime_error("GestaltCore::Value: tried to call a " + typeName());
      const Func& func = std::get<Func>(value);
      if (!func) {
          throw std::runtime_error("GestaltCore::Value: Fatal! Tried to call an empty/uninitialized Lambda.");
      }
      return std::get<Func>(value)(std::move(arg));
    }

    Value operator()(Value arg) const { return call(std::move(arg)); }


    const Value& operator[](const std::string& key) const {
        if (type != Type::Set) {
            throw std::runtime_error("GestaltCore::Value: Attempted to access field '" + key + "' on non-set");
        }
        const auto& set = std::get<Set>(value);
        auto it = set.find(key);
        if (it == set.end()) {
            throw std::runtime_error("GestaltCore::Value: Field '" + key + "' not found");
        }
        return it->second;
    }

    const Value& operator[](const Value& key) const {
        return (*this)[key.asString()];
    }

    bool operator==(const Value& other) const {
        // Nix allows comparing Ints and Floats (e.g., 1 == 1.0 is true)
        if (isNumber() && other.isNumber()) {
            if (type == Type::Int && other.type == Type::Int) {
                return asInt() == other.asInt();
            }
            return asFloat() == other.asFloat(); // Safe cross-type comparison
        }

        // If types don't match, they are not equal
        if (type != other.type) return false;

        // Perform value comparison based on the type
        switch (type) {
            case Type::Null:   return true;
            case Type::Bool:   return std::get<bool>(value) == std::get<bool>(other.value);
            case Type::Int:    return std::get<long long>(value) == std::get<long long>(other.value);
            case Type::Float:  return std::get<double>(value) == std::get<double>(other.value);
            case Type::String: return std::get<std::string>(value) == std::get<std::string>(other.value);
            
            // std::vector and std::map automatically call operator== recursively on their elements!
            // This guarantees deep comparison, not reference/pointer comparison.
            case Type::List:   return std::get<List>(value) == std::get<List>(other.value);
            case Type::Set:    return std::get<Set>(value) == std::get<Set>(other.value);
            
            case Type::Lambda: 
              return false;
        }
        return false;
    }

    Value update(const Value& other) const {
      if (type != Type::Set || other.type != Type::Set) {
        throw std::runtime_error("Update (//) requires two sets");
      }

      // 1. Create a copy of the current map (Left Hand Side)
      Set newMap = std::get<Set>(value);
      
      // 2. Iterate over the other map (Right Hand Side)
      const Set& otherMap = std::get<Set>(other.value);
      
      for (const auto& kv : otherMap) {
        // 3. Insert or Overwrite
        // newMap[key] = value
        newMap[kv.first] = kv.second; 
      }

      return Value::fromSet(std::move(newMap));
    }

    Value concat(const Value& other) const {
      if (type != Type::List || other.type != Type::List) {
        throw std::runtime_error("GestaltCore::Value: concatenation (++) requires two lists");
      }

      // 1. Access underlying vectors
      const List& list1 = std::get<List>(value);
      const List& list2 = std::get<List>(other.value);

      // 2. Create new vector and reserve memory
      List newList;
      newList.reserve(list1.size() + list2.size());

      // 3. Insert elements from both lists
      newList.insert(newList.end(), list1.begin(), list1.end());
      newList.insert(newList.end(), list2.begin(), list2.end());

      return Value::fromList(std::move(newList));
    }

  private:

        friend void to_json(nlohmann::json& j, const Value& v) {
        switch (v.type) {
            case Type::Null:   j = nullptr; break;
            case Type::Bool:   j = v.asBool(); break;
            case Type::Int:    j = v.asInt(); break;
            case Type::Float:  j = v.asFloat(); break;
            case Type::String: j = v.asString(); break;
            case Type::List:
                j = std::get<List>(v.value); // recursive call to to_json
                break;
            case Type::Set:
                j = std::get<Set>(v.value); // recursive call to to_json
                break;
            case Type::Lambda:
                throw std::runtime_error("toJSON: cannot serialize a lambda");
        }
    }

    friend void from_json(const nlohmann::json& j, Value& v) {
        if (j.is_null())         v = Value::null();
        else if (j.is_boolean())  v = Value::fromBool(j.get<bool>());
        else if (j.is_number_integer()) v = Value::fromInt(j.get<long long>());
        else if (j.is_number_float())   v = Value::fromFloat(j.get<double>());
        else if (j.is_string())   v = Value::fromString(j.get<std::string>());
        else if (j.is_array()) {
            List list;
            for (const auto& el : j) list.push_back(el.get<Value>());
            v = Value::fromList(std::move(list));
        }
        else if (j.is_object()) {
            Set set;
            for (auto it = j.begin(); it != j.end(); ++it) {
                set[it.key()] = it.value().get<Value>();
            }
            v = Value::fromSet(std::move(set));
        }
    }

    template <typename T>
    Value(Type t, T v) : type(t), value(std::move(v)) {}
  };
  using Observer = std::function<void(const Value&)>;

  explicit GestaltCore();

  static Value gestalt_primop_sub(Value x) {
    return Value::lambda([x](Value y) {
      if (x.isInt() && y.isInt()) {
        return Value::fromInt(x.asInt() - y.asInt());
      } else if (x.isNumber() && y.isNumber()) {
        return Value::fromFloat(x.asFloat() - y.asFloat());
      } else {
        throw std::runtime_error("gestalt_primop_sub: both arguments must be numbers");
      }
    });
  }

  static Value gestalt_primop_foldl_(Value func) {
    if (func.type != Value::Type::Lambda) {
      throw std::runtime_error("gestalt_primop_foldl_: expected a lambda function");
    }
    return Value::lambda([func](Value nul) {
      return Value::lambda([func, nul](Value list) {
        if (list.type != Value::Type::List) {
          throw std::runtime_error("gestalt_primop_foldl_: expected a list");
        }
        Value acc = nul;
        for (const auto& item : std::get<Value::List>(list.value)) {
          acc = func(acc)(item);
        }
        return acc;
      });
    });
  }

  static Value gestalt_primop_lessThan(Value x) {
    return Value::lambda([x](Value y) {
      if (x.isInt() && y.isInt()) {
        return Value::fromBool(x.asInt() < y.asInt());
      } else if (x.isNumber() && y.isNumber()) {
        return Value::fromBool(x.asFloat() < y.asFloat());
      } else {
        throw std::runtime_error("gestalt_primop_lessThan: both arguments must be numbers");
      }
    });
  }

  static Value gestalt_primop_map(Value func) {
    if (func.type != Value::Type::Lambda) {
      throw std::runtime_error("gestalt_primop_map: expected a lambda function");
    }
    return Value::lambda([func](Value list) {
      if (list.type != Value::Type::List) {
        throw std::runtime_error("gestalt_primop_map: expected a list");
      }
      const auto &inVec = std::get<Value::List>(list.value);
      Value::List result;
      result.reserve(inVec.size());
      for (const auto& item : inVec) {
        result.push_back(func(item));
      }
      return Value::fromList(std::move(result));
    });
  }
  static Value gestalt_primop_seq(Value x) {
    return Value::lambda([](Value y){
      return y;
    });
  }

  static Value gestalt_primop_concatMap(Value func) {
    if (func.type != Value::Type::Lambda) {
      throw std::runtime_error("gestalt_primop_concatMap: expected a lambda function");
    }
    return Value::lambda([func](Value list) {
      if (list.type != Value::Type::List) {
        throw std::runtime_error("gestalt_primop_concatMap: expected a list");
      }
      Value::List result;
      for (const auto& item : std::get<Value::List>(list.value)) {
        Value mapped = func(item);
        if (mapped.type != Value::Type::List) {
          throw std::runtime_error("gestalt_primop_concatMap: mapping function must return a list");
        }
        for (const auto& e : std::get<Value::List>(mapped.value)) result.push_back(e);
      }
      return Value::fromList(std::move(result));
    });
  }


  static Value gestalt_primop_toString(Value x) {
    if (x.isInt()) {
      return Value::fromString(std::to_string(x.asInt()));
    } else if (x.isFloat()) {
      return Value::fromString(std::to_string(x.asFloat()));
    } else if (x.isBool()) {
      return Value::fromString(x.asBool() ? "true" : "false");
    } else if (x.isString()) {
      return x; 
    } else if (x.type == Value::Type::Null) {
      return Value::fromString("");
    } else {
      throw std::runtime_error("gestalt_primop_toString: unsupported type");
    }
  }

  static Value gestalt_primop_typeOf(Value x) {
    return Value::fromString(x.typeName());
  }

  static Value gestalt_primop_length(Value x) {
    if (x.type != Value::Type::List) {
      throw std::runtime_error("gestalt_primop_length: expected a list");
    }
    return Value::fromInt(static_cast<long long>(std::get<Value::List>(x.value).size()));
  }

  static Value gestalt_primop_elemAt(Value list) {
    if (list.type != Value::Type::List) {
      throw std::runtime_error("gestalt_primop_elemAt: expected a list");
    }
    return Value::lambda([list](Value index) {
      if (!index.isInt()) {
        throw std::runtime_error("gestalt_primop_elemAt: index must be an integer");
      }
      long long idx = index.asInt();
      const auto& vec = std::get<Value::List>(list.value);
      if (idx < 0 || idx >= static_cast<long long>(vec.size())) {
        throw std::runtime_error("gestalt_primop_elemAt: index out of bounds");
      }
      return vec[idx];
    });
  }

    static Value gestalt_primop_genList(Value func) {
      if (func.type != Value::Type::Lambda) {
        throw std::runtime_error("gestalt_primop_genList: expected a lambda function");
      }
      return Value::lambda([func](Value nval) {
        if (!nval.isInt()) {
          throw std::runtime_error("gestalt_primop_genList: expected integer length");
        }
        long long n = nval.asInt();
        if (n < 0) throw std::runtime_error("gestalt_primop_genList: negative length");
        Value::List result;
        result.reserve(static_cast<size_t>(n));
        for (long long i = 0; i < n; ++i) {
          result.push_back(func(Value::fromInt(i)));
        }
        return Value::fromList(std::move(result));
      });
    }


  static Value gestalt_primop_filter(Value func) {
    if (func.type != Value::Type::Lambda) {
      throw std::runtime_error("gestalt_primop_filter: expected a lambda function");
    }
    return Value::lambda([func](Value list) {
      if (list.type != Value::Type::List) {
        throw std::runtime_error("gestalt_primop_filter: expected a list");
      }
      const auto &inVec = std::get<Value::List>(list.value);
      Value::List result;
      result.reserve(inVec.size());
      for (const auto& item : inVec) {
        if (func(item).isBool() && func(item).asBool()) {
          result.push_back(item);
        }
      }
      return Value::fromList(std::move(result));
    });
  }

  static Value gestalt_primop_all(Value func) {
    if (func.type != Value::Type::Lambda) {
      throw std::runtime_error("gestalt_primop_all: expected a lambda function");
    }
    return Value::lambda([func](Value list) {
      if (list.type != Value::Type::List) {
        throw std::runtime_error("gestalt_primop_all: expected a list");
      }
      for (const auto& item : std::get<Value::List>(list.value)) {
        if (!func(item).isBool() || !func(item).asBool()) {
          return Value::fromBool(false);
        }
      }
      return Value::fromBool(true);
    });
  }
  

  static Value gestalt_primop_elem(Value item) {
    return Value::lambda([item](Value list) {
      if (list.type != Value::Type::List) {
        throw std::runtime_error("gestalt_primop_elem: expected a list");
      }
      for (const auto& elem : std::get<Value::List>(list.value)) {
        if (elem == item) {
          return Value::fromBool(true);
        }
      }
      return Value::fromBool(false);
    });
  }

  static Value gestalt_primop_toJSON(Value v) {
      try {
          nlohmann::json j = v;
          return Value::fromString(j.dump());
      } catch (const std::exception& e) {
          throw std::runtime_error(std::string("toJSON failed: ") + e.what());
      }
  }

  static Value gestalt_primop_fromJSON(Value s) {
      if (!s.isString()) throw std::runtime_error("fromJSON: expected string");
      try {
          auto j = nlohmann::json::parse(s.asString());
          return j.get<Value>();
      } catch (const std::exception& e) {
          throw std::runtime_error(std::string("fromJSON failed: ") + e.what());
      }
  }

  static Value gestalt_primop_head(Value list) {
    if (list.type != Value::Type::List) {
      throw std::runtime_error("gestalt_primop_head: expected a list");
    }
    const auto& vec = std::get<Value::List>(list.value);
    if (vec.empty()) {
      throw std::runtime_error("gestalt_primop_head: cannot take head of an empty list");
    }
    return vec.front();
  }

  static Value gestalt_primop_trace(Value msg) {
    return Value::lambda([msg](Value x) {
      std::cout << "[TRACE] " << msg.asString() << ": " << gestalt_primop_toJSON(x).asString() << std::endl;
      return x;
    });
  }

  static Value gestalt_primop_concatStringsSep(Value sep) {
    if (!sep.isString()) {
      throw std::runtime_error("gestalt_primop_concatStringsSep: expected a string separator");
    }
    return Value::lambda([sep](Value list) {
      if (list.type != Value::Type::List) {
        throw std::runtime_error("gestalt_primop_concatStringsSep: expected a list");
      }
      const auto& vec = std::get<Value::List>(list.value);
      std::string result;
      for (size_t i = 0; i < vec.size(); ++i) {
        if (!vec[i].isString()) {
          throw std::runtime_error("gestalt_primop_concatStringsSep: all elements must be strings");
        }
        result += vec[i].asString();
        if (i < vec.size() - 1) {
          result += sep.asString();
        }
      }
      return Value::fromString(result);
    });
  }

  static Value gestalt_primop_hasAttr(Value key) {
    if (!key.isString()) {
      throw std::runtime_error("gestalt_primop_hasAttr: expected a string key");
    }
    return Value::lambda([key](Value set) {
      if (set.type != Value::Type::Set) {
        throw std::runtime_error("gestalt_primop_hasAttr: expected a set");
      }
      const auto& m = std::get<Value::Set>(set.value);
      return Value::fromBool(m.find(key.asString()) != m.end());
    });
  }

  static Value gestalt_primop_any(Value func) {
    if (func.type != Value::Type::Lambda) {
      throw std::runtime_error("gestalt_primop_any: expected a lambda function");
    }
    return Value::lambda([func](Value list) {
      if (list.type != Value::Type::List) {
        throw std::runtime_error("gestalt_primop_any: expected a list");
      }
      for (const auto& item : std::get<Value::List>(list.value)) {
        if (func(item).isBool() && func(item).asBool()) {
          return Value::fromBool(true);
        }
      }
      return Value::fromBool(false);
    });
  }

  static Value gestalt_primop_warn(Value msg) {
    if (!msg.isString()) {
      throw std::runtime_error("gestalt_primop_warn: expected a string message");
    }
    return Value::lambda([msg](Value x) {
      std::cerr << "[WARN] " << msg.asString();
      return x;
    });
  }

  static Value gestalt_primop_isPath(Value p){
    std::cerr << "[DEBUG] " << "paths not supported. isPath always returns false.";
    return Value::fromBool(false); 
  }

static Value gestalt_primop_substring(Value start) {
    if (!start.isInt()) {
      throw std::runtime_error("gestalt_primop_substring: expected integer start index");
    }
    return Value::lambda([start](Value lenVal) {
      if (!lenVal.isInt()) {
        throw std::runtime_error("gestalt_primop_substring: expected integer length");
      }
      return Value::lambda([start, lenVal](Value str) {
        if (!str.isString()) {
          throw std::runtime_error("gestalt_primop_substring: expected a string");
        }

        const std::string& s = str.asString();
        long long st = start.asInt();
        long long len = lenVal.asInt();
        long long s_size = static_cast<long long>(s.size());
        if (st < 0) {
            st = 0;
        }
        if (st >= s_size) {
            return Value::fromString("");
        }
        size_t count = std::string::npos; 
        if (len >= 0) {
            count = static_cast<size_t>(len);
        }
        return Value::fromString(s.substr(static_cast<size_t>(st), count));
      });
    });
  }

  static Value gestalt_primop_stringLength(Value str) {
    if (!str.isString()) {
      throw std::runtime_error("gestalt_primop_stringLength: expected a string");
    }
    return Value::fromInt(static_cast<long long>(str.asString().size()));
  }

  static Value gestalt_primop_mul(Value x) {
    return Value::lambda([x](Value y) {
      if (x.isInt() && y.isInt()) {
        return Value::fromInt(x.asInt() * y.asInt());
      } else if (x.isNumber() && y.isNumber()) {
        return Value::fromFloat(x.asFloat() * y.asFloat());
      } else {
        throw std::runtime_error("gestalt_primop_mul: both arguments must be numbers");
      }
    });
  }

  static Value gestalt_primop_div(Value x) {
    return Value::lambda([x](Value y) {
      if (x.isInt() && y.isInt()) {
        if (y.asInt() == 0) throw std::runtime_error("gestalt_primop_div: division by zero");
        return Value::fromInt(x.asInt() / y.asInt());
      } else if (x.isNumber() && y.isNumber()) {
        if (y.asFloat() == 0.0) throw std::runtime_error("gestalt_primop_div: division by zero");
        return Value::fromFloat(x.asFloat() / y.asFloat());
      } else {
        throw std::runtime_error("gestalt_primop_div: both arguments must be numbers");
      }
    });
  }

  static Value gestalt_add(Value x, Value y) {
    if (x.isInt() && y.isInt()) {
      return Value::fromInt(x.asInt() + y.asInt());
    } else if (x.isNumber() && y.isNumber()) {
      return Value::fromFloat(x.asFloat() + y.asFloat());
    } else if (x.isString() && y.isString()) {
      return Value::fromString(x.asString() + y.asString());
    } else {
      throw std::runtime_error("gestalt_add: both arguments must be numbers or strings");
    }
  }

  Value dispatch(const std::string& actionName, const Value& params = Value());

  void reset();

  void runUnitTests();

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
  Value unitTests_;
  Value meta_;

  size_t nextObserverId_ = 1;
  std::unordered_map<size_t, Observer> observers_;
};

