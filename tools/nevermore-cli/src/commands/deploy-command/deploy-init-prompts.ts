import inquirer from 'inquirer';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { getRobloxCookieAsync, createPlaceInUniverseAsync } from '../../utils/roblox-auth/index.js';

interface RobloxPlace {
  id: number;
  universeId: number;
  name: string;
  description: string;
}

async function listPlacesAsync(
  universeId: number
): Promise<RobloxPlace[]> {
  const places: RobloxPlace[] = [];
  let cursor: string | undefined;

  while (true) {
    const url = new URL(
      `https://develop.roblox.com/v1/universes/${universeId}/places`
    );
    url.searchParams.set('limit', '100');
    if (cursor) {
      url.searchParams.set('cursor', cursor);
    }

    const response = await fetch(url.toString());
    if (!response.ok) {
      throw new Error(
        `Failed to list places for universe ${universeId}: ${response.status}`
      );
    }

    const data = (await response.json()) as {
      data: RobloxPlace[];
      nextPageCursor: string | null;
    };

    places.push(...data.data);

    if (!data.nextPageCursor) {
      break;
    }
    cursor = data.nextPageCursor;
  }

  return places;
}

export async function promptPlaceIdAsync(
  universeId: number,
  placeName: string
): Promise<number> {
  let places: RobloxPlace[] = [];
  try {
    OutputHelper.info(`Fetching places for universe ${universeId}...`);
    places = await listPlacesAsync(universeId);
  } catch {
    OutputHelper.warn(
      `Could not fetch places (universe may be private or not exist).`
    );
  }

  const choices: Array<{ name: string; value: number | string }> = [
    { name: '+ Create new place', value: 'create' },
    ...places.map((p) => ({
      name: `${p.name} (${p.id})`,
      value: p.id,
    })),
    { name: 'Enter place ID manually', value: 'manual' },
  ];

  const { selection } = await inquirer.prompt([
    {
      type: 'select',
      name: 'selection',
      message:
        places.length > 0 ? 'Select a place:' : 'No existing places found:',
      choices,
    },
  ]);

  if (selection === 'create') {
    return await createNewPlaceInteractiveAsync(universeId, placeName);
  }

  if (selection === 'manual') {
    const { manualPlaceId } = await inquirer.prompt([
      {
        type: 'number',
        name: 'manualPlaceId',
        message: 'Place ID:',
        validate: (input: number) =>
          Number.isInteger(input) && input > 0
            ? true
            : 'Must be a positive integer',
      },
    ]);
    return manualPlaceId;
  }

  if (typeof selection !== 'number' || !Number.isFinite(selection) || selection <= 0) {
    throw new Error('No place selected.');
  }

  return selection;
}

async function createNewPlaceInteractiveAsync(
  universeId: number,
  defaultPlaceName: string
): Promise<number> {
  const { placeName } = await inquirer.prompt([
    {
      type: 'input',
      name: 'placeName',
      message: 'New place name:',
      default: defaultPlaceName,
    },
  ]);

  const cookie = await getRobloxCookieAsync();
  return await createPlaceInUniverseAsync(cookie, universeId, placeName);
}
