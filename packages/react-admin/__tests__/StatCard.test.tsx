import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import StatCard from '../components/dashboard/StatCard'

describe('StatCard', () => {
  it('renders label and formatted value', () => {
    render(<StatCard label="Total Users" value={1234} />)
    expect(screen.getByText('Total Users')).toBeInTheDocument()
    expect(screen.getByText('1,234')).toBeInTheDocument()
  })

  it('renders skeleton when loading', () => {
    render(<StatCard label="Total Users" value={0} loading={true} />)
    expect(screen.getByTestId('stat-skeleton')).toBeInTheDocument()
  })

  it('renders value 0 correctly (not skeleton)', () => {
    render(<StatCard label="Active Events" value={0} loading={false} />)
    expect(screen.getByText('Active Events')).toBeInTheDocument()
    expect(screen.getByText('0')).toBeInTheDocument()
  })

  it('formats large numbers with commas', () => {
    render(<StatCard label="Connections" value={12345} />)
    expect(screen.getByText('12,345')).toBeInTheDocument()
  })
})
