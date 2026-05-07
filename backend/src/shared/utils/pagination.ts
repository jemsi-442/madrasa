export type PaginationQuery = {
  page: number;
  pageSize: number;
};

export const getPaginationParams = (query: PaginationQuery) => ({
  page: query.page,
  pageSize: query.pageSize,
  skip: (query.page - 1) * query.pageSize,
  take: query.pageSize,
});

export const buildPaginationMeta = (totalItems: number, query: PaginationQuery) => ({
  page: query.page,
  pageSize: query.pageSize,
  totalItems,
  totalPages: Math.max(1, Math.ceil(totalItems / query.pageSize)),
});

