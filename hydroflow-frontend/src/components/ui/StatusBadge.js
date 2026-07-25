// ─────────────────────────────────────────
// STATUS BADGE COMPONENT
// Reusable colored badge for order status
// ─────────────────────────────────────────
const STATUS_STYLES = {
  PENDING: {
    bg: '#FFF7ED',
    color: '#EA580C',
    label: '⏳ Pending'
  },
  PAID: {
    bg: '#F0FDF4',
    color: '#16A34A',
    label: '💳 Paid'
  },
  ASSIGNED: {
    bg: '#EFF6FF',
    color: '#2563EB',
    label: '👤 Assigned'
  },
  IN_TRANSIT: {
    bg: '#F5F3FF',
    color: '#7C3AED',
    label: '🚛 In Transit'
  },
  DELIVERED: {
    bg: '#ECFDF5',
    color: '#059669',
    label: '📦 Delivered'
  },
  COMPLETED: {
    bg: '#F0FDF4',
    color: '#16A34A',
    label: '✅ Completed'
  },
  CANCELLED: {
    bg: '#FEF2F2',
    color: '#DC2626',
    label: '❌ Cancelled'
  },
  DISPUTED: {
    bg: '#FEF2F2',
    color: '#DC2626',
    label: '⚠️ Disputed'
  }
};

const StatusBadge = ({ status }) => {
  const style = STATUS_STYLES[status] || {
    bg: '#F8FAFC',
    color: '#64748B',
    label: status
  };

  return (
    <span style={{
      display: 'inline-block',
      padding: '4px 12px',
      borderRadius: '999px',
      fontSize: '12px',
      fontWeight: '600',
      background: style.bg,
      color: style.color
    }}>
      {style.label}
    </span>
  );
};

export default StatusBadge;