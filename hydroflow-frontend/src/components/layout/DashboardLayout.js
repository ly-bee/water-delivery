import Sidebar from './Sidebar';
import TopBar from './TopBar';

const DashboardLayout = ({ children }) => (
  <div className="page-wrapper">
    <Sidebar />
    <div className="page-right">
      <TopBar />
      <main className="page-main">{children}</main>
    </div>
  </div>
);

export default DashboardLayout;
