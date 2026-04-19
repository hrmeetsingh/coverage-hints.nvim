function add(a, b) {
  return a + b;
}

function mul(a, b) {
  return a * b;
}

function divide(a, b) {
  if (b === 0) {
    throw new Error("div by zero");
  }
  return a / b;
}

module.exports = { add, mul, divide };
