import React from 'react';
import { render, screen } from '@testing-library/react';
import StatCard from '@/components/dashboard/StatCard';

describe('StatCard', () => {
  it('renders label and formatted value', () => {
    render(<StatCard label="Total Users" value={1234} />);
    expect(screen.getByText('Total Users')).toBeInTheDocument();
    expect(screen.getByText('1,234')).toBeInTheDocument();
  });

  it('renders skeleton when loading', () => {
    render(<StatCard label="Total Users" value={0} loading />);
    expect(screen.getByTestId('stat-skeleton')).toBeInTheDocument();
  });
});
