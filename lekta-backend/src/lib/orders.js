import { randomUUID } from 'crypto';

export function makeOrderId() {
  return `ord_${randomUUID()}`;
}

export function makeExternalReference(orderId) {
  return `lekta-${orderId}`;
}

export function normalizeOrderItems(items) {
  if (!Array.isArray(items) || items.length === 0) {
    throw new Error('items must be a non-empty array');
  }

  return items.map((item, index) => {
    const title = item.name || item.title;
    const unitPrice = Number(item.unit_price);
    const quantity = Number(item.quantity);

    if (!title?.trim()) throw new Error(`items[${index}].name is required`);
    if (!Number.isFinite(unitPrice) || unitPrice < 0) {
      throw new Error(`items[${index}].unit_price must be >= 0`);
    }
    if (!Number.isInteger(quantity) || quantity <= 0) {
      throw new Error(`items[${index}].quantity must be a positive integer`);
    }

    return {
      barcode: item.barcode?.trim() || null,
      title: title.trim(),
      unit_price: Math.round(unitPrice * 100) / 100,
      quantity,
    };
  });
}

export function calculateTotal(items) {
  const cents = items.reduce((sum, item) => {
    return sum + Math.round(Number(item.unit_price) * 100) * Number(item.quantity);
  }, 0);
  return cents / 100;
}

export function mapPaymentStatus(mpStatus) {
  switch (mpStatus) {
  case 'approved':
    return 'approved';
  case 'rejected':
    return 'rejected';
  case 'cancelled':
    return 'cancelled';
  case 'refunded':
  case 'charged_back':
    return 'cancelled';
  default:
    return 'pending';
  }
}
