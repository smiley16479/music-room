import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params }) => {
  // Skip loading individual playlist data during SSR to avoid auth issues
  // The component will handle loading the data on the client side
  return {
    playlistId: params.id
  };
};
