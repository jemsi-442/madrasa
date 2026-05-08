type LoadingStatsGridProps = {
  cards?: number;
};

type LoadingRowListProps = {
  rows?: number;
};

type LoadingTableProps = {
  columns: number;
  rows?: number;
};

export const LoadingStatsGrid = ({ cards = 4 }: LoadingStatsGridProps) => (
  <div className="stats-grid" aria-hidden="true">
    {Array.from({ length: cards }).map((_, index) => (
      <article key={index} className="stat-card">
        <div className="skeleton-line skeleton-label" />
        <div className="skeleton-line skeleton-value" />
        <div className="skeleton-line skeleton-text" />
      </article>
    ))}
  </div>
);

export const LoadingRowList = ({ rows = 4 }: LoadingRowListProps) => (
  <div className="row-list" aria-hidden="true">
    {Array.from({ length: rows }).map((_, index) => (
      <div key={index} className="row-item skeleton-row">
        <div className="skeleton-line skeleton-text" />
        <div className="skeleton-line skeleton-short" />
      </div>
    ))}
  </div>
);

export const LoadingTable = ({ columns, rows = 5 }: LoadingTableProps) => (
  <div className="table-wrap" aria-hidden="true">
    <table>
      <tbody>
        {Array.from({ length: rows }).map((_, rowIndex) => (
          <tr key={rowIndex}>
            {Array.from({ length: columns }).map((__, columnIndex) => (
              <td key={columnIndex}>
                <div className="skeleton-line skeleton-text" />
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  </div>
);

export const InlineEmptyState = ({ message }: { message: string }) => (
  <p className="empty-state empty-state-card">{message}</p>
);
