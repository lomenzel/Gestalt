(function __gestalt_deep_equal(a) {
  return (b) => {
    if (a === b) return true;
    if (a == null || b == null) return false;
    if (typeof a !== typeof b) return false;

    if (Array.isArray(a)) {
      if (!Array.isArray(b) || a.length !== b.length) return false;
      for (let i = 0; i < a.length; i++) {
        if (!__gestalt_deep_equal(a[i])(b[i])) return false;
      }
      return true;
    }

    if (typeof a === "object") {
      const aKeys = Object.keys(a);
      const bKeys = Object.keys(b);
      if (aKeys.length !== bKeys.length) return false;
      for (let key of aKeys) {
        if (!b.hasOwnProperty(key) || !__gestalt_deep_equal(a[key])(b[key]))
          return false;
      }
      return true;
    }

    return false;
  };
});
