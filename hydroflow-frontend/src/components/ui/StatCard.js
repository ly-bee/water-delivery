/* Simple wrapper — internal pages now use .stat-card CSS class directly */
const StatCard = ({ title, value, subtitle }) => (
  <div className="stat-card">
    <p className="stat-label">{title}</p>
    <p className="stat-value">{value}</p>
    {subtitle && <p className="stat-sub">{subtitle}</p>}
  </div>
);

export default StatCard;
