import { LearnerXRay } from '../../../components/learner-xray';

type Props = { params: Promise<{ userId: string }> };

export default async function UserDetailPage({ params }: Props) {
  const { userId } = await params;
  return <LearnerXRay userId={userId} />;
}
