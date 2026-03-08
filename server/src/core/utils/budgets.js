const { toNumber } = require("./validation");

function calcBudgetTotals(items, discount, tax) {
  const subtotal = items.reduce((sum, item) => sum + item.qty * item.unit_price, 0);
  const discountValue = toNumber(discount);
  const taxValue = toNumber(tax);
  return {
    subtotal,
    discount: discountValue,
    tax: taxValue,
    total: subtotal - discountValue + taxValue
  };
}

module.exports = { calcBudgetTotals };
