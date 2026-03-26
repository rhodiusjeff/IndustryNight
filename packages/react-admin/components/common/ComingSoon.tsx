import EmptyState from '@/components/common/EmptyState';

interface ComingSoonProps {
  screenName: string;
}

export default function ComingSoon({ screenName }: ComingSoonProps): JSX.Element {
  return <EmptyState title={`Coming soon - ${screenName}`} description="This screen scaffold is in place for B1+ implementation." />;
}
