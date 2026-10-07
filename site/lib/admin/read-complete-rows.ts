type Row = Record<string, unknown>;
type PageResult = { data: Row[] | null; error: { message: string } | null };

/** Fetch complete, stably ordered results, including API caps below 1000. */
export async function readCompleteRows(
  fetchPage: (from: number, to: number) => PromiseLike<PageResult>,
): Promise<Row[]> {
  const rows: Row[] = [];
  while (true) {
    const { data, error } = await fetchPage(rows.length, rows.length + 999);
    // Never turn a failed or partial roster into a misleading zero count.
    if (error) throw new Error('تعذر تحميل بيانات الاجتماعات والمخدومين كاملة. أعد المحاولة.');
    if (!data?.length) return rows;
    rows.push(...data);
  }
}
