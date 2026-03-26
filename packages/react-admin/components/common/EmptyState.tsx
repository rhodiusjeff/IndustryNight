interface EmptyStateProps {
  title: string;
  description?: string;
}

export default function EmptyState({ title, description }: EmptyStateProps): JSX.Element {
  return (
    <div className="flex min-h-[320px] items-center justify-center">
      <div className="text-center">
        <h2 className="text-xl font-semibold text-foreground">{title}</h2>
        {description ? <p className="mt-2 text-sm text-muted-foreground">{description}</p> : null}
      </div>
    </div>
  );
}
