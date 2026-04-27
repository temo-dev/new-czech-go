import { DashboardStatsBar } from '../components/dashboard-stats';
import { ExerciseDashboard } from '../components/exercise-dashboard';

export default function HomePage() {
  return (
    <>
      <DashboardStatsBar />
      <ExerciseDashboard />
    </>
  );
}
