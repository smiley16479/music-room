import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params }) => {
  // The individual event page doesn't need to load data here
  // since it loads the event data in the component itself
  return {};
};
