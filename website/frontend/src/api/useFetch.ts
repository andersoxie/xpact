import { useEffect, useState } from "react";

/** Load data once when the component mounts. */
export function useFetch<T>(load: () => Promise<T>) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;
    load()
      .then((value) => alive && setData(value))
      .catch((e: Error) => alive && setError(e.message));
    return () => {
      alive = false;
    };
    // The loaders are module-level functions, so running once is intended.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return { data, error, loading: data === null && error === null };
}
