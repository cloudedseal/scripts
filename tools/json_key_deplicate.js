function findDuplicateKeys(data) {
  const seen = {};

  function traverse(obj, path) {
    if (Array.isArray(obj)) {
      obj.forEach((item, index) => {
        traverse(item, `${path}[${index}]`);
      });
    } else if (obj !== null && typeof obj === "object") {
      Object.keys(obj).forEach(key => {
        const newPath = path ? `${path}.${key}` : key;

        // record key occurrence
        if (!seen[key]) seen[key] = [];
        seen[key].push(newPath);

        traverse(obj[key], newPath);
      });
    }
  }

  traverse(data, "");

  // return only keys that appear more than once
  const duplicates = {};
  for (const key in seen) {
    if (seen[key].length > 1) {
      duplicates[key] = seen[key];
    }
  }

  return duplicates;
}
