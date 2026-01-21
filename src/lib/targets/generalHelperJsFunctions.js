function deepEqual(a, b) {
  if (a === b) return true;                  // identical primitives or same reference
  if (a == null || b == null) return false;   // one is null/undefined
  if (typeof a !== typeof b) return false;

  if (Array.isArray(a)) {
    if (!Array.isArray(b) || a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) {
      if (!deepEqual(a[i], b[i])) return false;
    }
    return true;
  }

  if (typeof a === 'object') {
    const aKeys = Object.keys(a);
    const bKeys = Object.keys(b);
    if (aKeys.length !== bKeys.length) return false;
    for (let key of aKeys) {
      if (!b.hasOwnProperty(key) || !deepEqual(a[key], b[key])) return false;
    }
    return true;
  }

  return false; // different primitive values
}

function elem(item, list) {
  for (let i = 0; i < list.length; i++) {
    if (deepEqual(list[i], item)) return true;
  }
  return false;
}