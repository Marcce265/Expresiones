#!/usr/bin/env node

/**
 * Validate and seed scripts/catalog_seed.json into Supabase.
 *
 * Safe defaults:
 *   node scripts/seed_supabase.mjs             # validation only
 *   node scripts/seed_supabase.mjs --apply     # database upsert
 *   node scripts/seed_supabase.mjs --apply --upload-images
 *
 * Production writes require all three environment variables:
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 *   ALLOW_SUPABASE_SEED=<project-ref>.supabase.co
 *
 * The service-role key is read only from the process environment. Never put it
 * in Flutter, a dart-define file, Git, Cloudflare Pages or browser JavaScript.
 */

import { execFile } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';

const execFileAsync = promisify(execFile);
const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, '..');
const catalogPath = path.join(scriptDir, 'catalog_seed.json');
const apply = process.argv.includes('--apply');
const uploadImages = process.argv.includes('--upload-images');
const allowedCategories = new Map([
  ['materials', { name: 'Materiales', kind: 'material', sort_order: 10 }],
  ['bouquets', { name: 'Ramos', kind: 'bouquet', sort_order: 20 }],
  [
    'personalized_gifts',
    { name: 'Regalos personalizados', kind: 'gift', sort_order: 30 },
  ],
]);
const slugPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const validStockStatuses = new Set([
  'in_stock',
  'low_stock',
  'out_of_stock',
  'made_to_order',
  'check_availability',
]);

function fail(message) {
  throw new Error(message);
}

function optionalText(value) {
  const text = value == null ? '' : String(value).trim();
  return text === '' ? null : text;
}

function nonNegativeNumber(value, label, { nullable = false } = {}) {
  if ((value == null || value === '') && nullable) return null;
  const parsed = Number(value ?? 0);
  if (!Number.isFinite(parsed) || parsed < 0) fail(`${label}: número inválido.`);
  return parsed;
}

function optionalNonNegativeInteger(value, label) {
  if (value == null || value === '') return null;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 0) {
    fail(`${label}: entero inválido.`);
  }
  return parsed;
}

function validateTier(tier, owner) {
  if (tier == null || typeof tier !== 'object' || Array.isArray(tier)) {
    fail(`${owner}: tramo de precio inválido.`);
  }
  const minQuantity = Number(tier.minQuantity);
  const unitPrice = Number(tier.unitPrice);
  if (!Number.isInteger(minQuantity) || minQuantity < 1) {
    fail(`${owner}: minQuantity inválido.`);
  }
  if (!Number.isFinite(unitPrice) || unitPrice < 0) {
    fail(`${owner}: unitPrice inválido.`);
  }
  return { minQuantity, unitPrice, label: optionalText(tier.label) };
}

async function loadAndValidateCatalog() {
  const raw = await fs.readFile(catalogPath, 'utf8');
  const catalog = JSON.parse(raw);
  if (!Array.isArray(catalog) || catalog.length === 0) {
    fail('scripts/catalog_seed.json debe contener una lista no vacía.');
  }

  const familySlugs = new Set();
  const familySkus = new Set();
  const variantSkus = new Set();
  const imagePaths = new Set();
  let activeFamilies = 0;
  let variants = 0;
  let visibleVariants = 0;
  let familyTiers = 0;
  let variantTiers = 0;
  let referencePricesNormalized = 0;

  for (const family of catalog) {
    const slug = optionalText(family.id);
    if (!slugPattern.test(slug ?? '')) fail(`Familia con id inválido: ${slug}`);
    if (familySlugs.has(slug)) fail(`Familia duplicada: ${slug}`);
    familySlugs.add(slug);
    if (!optionalText(family.name)) fail(`${slug}: falta el nombre.`);
    if (!allowedCategories.has(family.category)) {
      fail(`${slug}: categoría desconocida ${family.category}.`);
    }
    nonNegativeNumber(family.basePrice, `${slug}.basePrice`);
    if (!validStockStatuses.has(family.stockStatus ?? 'check_availability')) {
      fail(`${slug}: stockStatus inválido.`);
    }
    optionalNonNegativeInteger(family.stock, `${slug}.stock`);
    optionalNonNegativeInteger(family.leadDays ?? 0, `${slug}.leadDays`);
    optionalNonNegativeInteger(
      family.productionPoints ?? 0,
      `${slug}.productionPoints`,
    );
    const familySku = optionalText(family.sku)?.toLowerCase();
    if (familySku && familySkus.has(familySku)) {
      fail(`SKU de familia duplicado: ${family.sku}`);
    }
    if (familySku) familySkus.add(familySku);
    if (!Array.isArray(family.variants)) fail(`${slug}: variants no es lista.`);
    if (!Array.isArray(family.priceTiers ?? [])) {
      fail(`${slug}: priceTiers no es lista.`);
    }
    const familyTierQuantities = new Set();
    for (const tier of family.priceTiers ?? []) {
      const parsed = validateTier(tier, slug);
      if (familyTierQuantities.has(parsed.minQuantity)) {
        fail(`${slug}: minQuantity repetido ${parsed.minQuantity}.`);
      }
      familyTierQuantities.add(parsed.minQuantity);
      familyTiers += 1;
    }
    if (family.priceIsEstimate === true) referencePricesNormalized += 1;
    if (family.imageUrl) imagePaths.add(family.imageUrl);

    const variantSlugs = new Set();
    for (const variant of family.variants) {
      variants += 1;
      const variantSlug = optionalText(variant.id);
      if (!slugPattern.test(variantSlug ?? '')) {
        fail(`${slug}: variante con id inválido: ${variantSlug}`);
      }
      if (variantSlugs.has(variantSlug)) {
        fail(`${slug}: variante duplicada ${variantSlug}.`);
      }
      variantSlugs.add(variantSlug);
      if (!optionalText(variant.name)) fail(`${slug}/${variantSlug}: falta nombre.`);
      const sku = optionalText(variant.sku)?.toLowerCase();
      if (sku && variantSkus.has(sku)) fail(`SKU de variante duplicado: ${variant.sku}`);
      if (sku) variantSkus.add(sku);
      if (!validStockStatuses.has(variant.stockStatus ?? 'check_availability')) {
        fail(`${slug}/${variantSlug}: stockStatus inválido.`);
      }
      nonNegativeNumber(
        variant.priceOverride,
        `${slug}/${variantSlug}.priceOverride`,
        { nullable: true },
      );
      optionalNonNegativeInteger(variant.stock, `${slug}/${variantSlug}.stock`);
      optionalNonNegativeInteger(
        variant.leadDays,
        `${slug}/${variantSlug}.leadDays`,
      );
      optionalNonNegativeInteger(
        variant.productionPoints,
        `${slug}/${variantSlug}.productionPoints`,
      );
      if (!Array.isArray(variant.priceTiers ?? [])) {
        fail(`${slug}/${variantSlug}: priceTiers no es lista.`);
      }
      const variantTierQuantities = new Set();
      for (const tier of variant.priceTiers ?? []) {
        const parsed = validateTier(tier, `${slug}/${variantSlug}`);
        if (variantTierQuantities.has(parsed.minQuantity)) {
          fail(`${slug}/${variantSlug}: minQuantity repetido.`);
        }
        variantTierQuantities.add(parsed.minQuantity);
        variantTiers += 1;
      }
      if (variant.imageUrl) imagePaths.add(variant.imageUrl);
      if (family.isActive === true && variant.isActive !== false) {
        visibleVariants += 1;
      }
    }
    if (family.isActive === true) activeFamilies += 1;
  }

  const missingImages = [];
  for (const relativePath of imagePaths) {
    try {
      const info = await fs.stat(path.resolve(projectRoot, relativePath));
      if (!info.isFile()) missingImages.push(relativePath);
    } catch {
      missingImages.push(relativePath);
    }
  }
  if (missingImages.length > 0) {
    fail(`Faltan ${missingImages.length} imágenes: ${missingImages.slice(0, 5).join(', ')}`);
  }

  const summary = {
    families: catalog.length,
    activeFamilies,
    variants,
    visibleVariants,
    familyTiers,
    variantTiers,
    uniqueImages: imagePaths.size,
    referencePricesNormalized,
  };
  const expected = {
    families: 37,
    activeFamilies: 31,
    variants: 238,
    visibleVariants: 223,
    familyTiers: 29,
    variantTiers: 0,
    uniqueImages: 221,
  };
  for (const [key, value] of Object.entries(expected)) {
    if (summary[key] !== value) {
      fail(`Conteo inesperado ${key}: ${summary[key]} (esperado ${value}).`);
    }
  }
  return { catalog, imagePaths, summary };
}

function requireProductionConfiguration() {
  const rawUrl = optionalText(process.env.SUPABASE_URL);
  const serviceRole = optionalText(process.env.SUPABASE_SERVICE_ROLE_KEY);
  const confirmation = optionalText(process.env.ALLOW_SUPABASE_SEED);
  if (!rawUrl || !serviceRole || !confirmation) {
    fail(
      'Para --apply define SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY y ' +
        'ALLOW_SUPABASE_SEED.',
    );
  }
  const url = new URL(rawUrl);
  if (url.protocol !== 'https:' && !['127.0.0.1', 'localhost'].includes(url.hostname)) {
    fail('SUPABASE_URL debe usar HTTPS (salvo Supabase local).');
  }
  if (confirmation !== url.host) {
    fail(`Confirmación incorrecta: ALLOW_SUPABASE_SEED debe ser ${url.host}.`);
  }
  return { baseUrl: url.origin, serviceRole };
}

function apiHeaders(serviceRole, extra = {}) {
  return {
    apikey: serviceRole,
    authorization: `Bearer ${serviceRole}`,
    ...extra,
  };
}

async function requestJson(config, method, pathname, { body, headers = {} } = {}) {
  const response = await fetch(`${config.baseUrl}${pathname}`, {
    method,
    headers: apiHeaders(config.serviceRole, {
      accept: 'application/json',
      ...(body === undefined ? {} : { 'content-type': 'application/json' }),
      ...headers,
    }),
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  if (!response.ok) {
    fail(`${method} ${pathname}: ${response.status} ${text.slice(0, 1000)}`);
  }
  return text === '' ? null : JSON.parse(text);
}

async function upsertRows(config, table, rows, onConflict, select) {
  const results = [];
  for (let offset = 0; offset < rows.length; offset += 100) {
    const chunk = rows.slice(offset, offset + 100);
    const query = new URLSearchParams({ on_conflict: onConflict, select });
    const response = await requestJson(
      config,
      'POST',
      `/rest/v1/${table}?${query}`,
      {
        body: chunk,
        headers: {
          prefer: 'resolution=merge-duplicates,return=representation',
        },
      },
    );
    results.push(...(response ?? []));
  }
  return results;
}

async function mapWithConcurrency(items, concurrency, callback) {
  const values = [...items];
  const results = new Array(values.length);
  let cursor = 0;
  async function worker() {
    for (;;) {
      const index = cursor++;
      if (index >= values.length) return;
      results[index] = await callback(values[index], index);
    }
  }
  await Promise.all(Array.from({ length: concurrency }, worker));
  return results;
}

async function optimizeAndUploadImages(config, imagePaths) {
  try {
    await execFileAsync('magick', ['-version']);
  } catch {
    fail('--upload-images requiere ImageMagick (`magick`) en PATH.');
  }
  const temporaryRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'expresiones-images-'));
  const mappings = new Map();
  try {
    await mapWithConcurrency(imagePaths, 4, async (relativePath) => {
      const source = path.resolve(projectRoot, relativePath);
      const bytes = await fs.readFile(source);
      const digest = crypto.createHash('sha256').update(bytes).digest('hex');
      const localThumb = path.join(temporaryRoot, `${digest}-thumb.webp`);
      const localDetail = path.join(temporaryRoot, `${digest}-detail.webp`);
      await Promise.all([
        execFileAsync('magick', [
          source,
          '-auto-orient',
          '-thumbnail',
          '400x400>',
          '-strip',
          '-quality',
          '75',
          localThumb,
        ]),
        execFileAsync('magick', [
          source,
          '-auto-orient',
          '-thumbnail',
          '1200x1200>',
          '-strip',
          '-quality',
          '80',
          localDetail,
        ]),
      ]);
      const thumbPath = `images/${digest}/thumb.webp`;
      const detailPath = `images/${digest}/detail.webp`;
      await Promise.all([
        uploadStorageObject(config, thumbPath, await fs.readFile(localThumb)),
        uploadStorageObject(config, detailPath, await fs.readFile(localDetail)),
      ]);
      mappings.set(relativePath, { thumbPath, detailPath });
    });
  } finally {
    await fs.rm(temporaryRoot, { recursive: true, force: true });
  }
  return mappings;
}

async function uploadStorageObject(config, objectPath, bytes) {
  const encodedPath = objectPath.split('/').map(encodeURIComponent).join('/');
  const response = await fetch(
    `${config.baseUrl}/storage/v1/object/catalog/${encodedPath}`,
    {
      method: 'POST',
      headers: apiHeaders(config.serviceRole, {
        'content-type': 'image/webp',
        'x-upsert': 'true',
      }),
      body: bytes,
    },
  );
  if (!response.ok) {
    fail(`Storage ${objectPath}: ${response.status} ${(await response.text()).slice(0, 500)}`);
  }
}

function imageColumns(sourcePath, imageMappings, prefix) {
  if (!sourcePath) {
    return {
      [`${prefix}_path`]: null,
      [`${prefix}_thumb_path`]: null,
      [`${prefix}_detail_path`]: null,
    };
  }
  const uploaded = imageMappings.get(sourcePath);
  return {
    [`${prefix}_path`]: uploaded?.detailPath ?? sourcePath,
    [`${prefix}_thumb_path`]: uploaded?.thumbPath ?? null,
    [`${prefix}_detail_path`]: uploaded?.detailPath ?? null,
  };
}

function variantImageColumns(sourcePath, imageMappings) {
  const uploaded = sourcePath ? imageMappings.get(sourcePath) : null;
  return {
    image_path: uploaded?.detailPath ?? optionalText(sourcePath),
    thumb_path: uploaded?.thumbPath ?? null,
    detail_path: uploaded?.detailPath ?? null,
  };
}

async function seed(config, catalog, imagePaths) {
  const imageMappings = uploadImages
    ? await optimizeAndUploadImages(config, imagePaths)
    : new Map();

  const categoryRows = [...allowedCategories].map(([slug, value]) => ({
    slug,
    name: value.name,
    kind: value.kind,
    sort_order: value.sort_order,
    active: true,
  }));
  const categories = await upsertRows(
    config,
    'categories',
    categoryRows,
    'slug',
    'id,slug,kind',
  );
  const categoryBySlug = new Map(categories.map((item) => [item.slug, item]));
  if (categoryBySlug.size !== allowedCategories.size) fail('No se resolvieron las categorías.');

  const familyRows = catalog.map((family) => {
    const category = categoryBySlug.get(family.category);
    const images = imageColumns(family.imageUrl, imageMappings, 'cover');
    return {
      slug: family.id,
      name: family.name,
      category_id: category.id,
      kind: category.kind,
      description: family.description ?? '',
      sku: optionalText(family.sku),
      sale_unit: optionalText(family.unitLabel) ?? 'unidad',
      base_price: Number(family.basePrice),
      starting_at: family.startingAt === true,
      // Business decision: every current price is definitive at launch.
      price_is_reference: false,
      stock_count: family.stock ?? null,
      stock_status: family.stockStatus ?? 'check_availability',
      prep_days: family.leadDays ?? 0,
      production_points: family.productionPoints ?? 0,
      tags: family.tags ?? [],
      attributes: family.attributes ?? {},
      ...images,
      active: family.isActive !== false,
      featured: family.isFeatured === true,
      sort_order: family.sortOrder ?? 0,
    };
  });
  const families = await upsertRows(
    config,
    'families',
    familyRows,
    'slug',
    'id,slug,active',
  );
  const familyBySlug = new Map(families.map((item) => [item.slug, item]));
  if (familyBySlug.size !== catalog.length) fail('No se resolvieron todas las familias.');

  const variantRows = [];
  for (const family of catalog) {
    const familyId = familyBySlug.get(family.id).id;
    family.variants.forEach((variant, index) => {
      variantRows.push({
        family_id: familyId,
        slug: variant.id,
        name: variant.name,
        sku: optionalText(variant.sku),
        color_hex: optionalText(variant.colorHex),
        attributes: variant.attributes ?? {},
        base_price: variant.priceOverride ?? null,
        price_is_reference: false,
        stock_count: variant.stock ?? null,
        stock_status: variant.stockStatus ?? 'check_availability',
        prep_days: variant.leadDays ?? null,
        production_points: variant.productionPoints ?? null,
        ...variantImageColumns(variant.imageUrl, imageMappings),
        active: variant.isActive !== false,
        sort_order: index,
      });
    });
  }
  const variants = await upsertRows(
    config,
    'variants',
    variantRows,
    'family_id,slug',
    'id,family_id,slug',
  );
  const variantByKey = new Map(
    variants.map((item) => [`${item.family_id}:${item.slug}`, item]),
  );
  if (variantByKey.size !== variantRows.length) fail('No se resolvieron todas las variantes.');

  const familyTierRows = [];
  const variantTierRows = [];
  for (const family of catalog) {
    const familyId = familyBySlug.get(family.id).id;
    for (const tier of family.priceTiers ?? []) {
      familyTierRows.push({
        family_id: familyId,
        min_qty: tier.minQuantity,
        unit_price: tier.unitPrice,
        label: optionalText(tier.label),
      });
    }
    for (const variant of family.variants) {
      const variantId = variantByKey.get(`${familyId}:${variant.id}`).id;
      for (const tier of variant.priceTiers ?? []) {
        variantTierRows.push({
          variant_id: variantId,
          min_qty: tier.minQuantity,
          unit_price: tier.unitPrice,
          label: optionalText(tier.label),
        });
      }
    }
  }
  if (familyTierRows.length > 0) {
    await upsertRows(
      config,
      'family_price_tiers',
      familyTierRows,
      'family_id,min_qty',
      'id',
    );
  }
  if (variantTierRows.length > 0) {
    await upsertRows(
      config,
      'variant_price_tiers',
      variantTierRows,
      'variant_id,min_qty',
      'id',
    );
  }

  return {
    categories: categories.length,
    families: families.length,
    variants: variants.length,
    familyTiers: familyTierRows.length,
    variantTiers: variantTierRows.length,
    uploadedImages: imageMappings.size,
  };
}

async function main() {
  const { catalog, imagePaths, summary } = await loadAndValidateCatalog();
  console.log('Catálogo validado:', summary);
  console.log(
    `${summary.referencePricesNormalized} indicadores priceIsEstimate del archivo ` +
      'se normalizarán a false por decisión del negocio.',
  );
  if (!apply) {
    console.log('Simulación completada. No se escribió en Supabase.');
    return;
  }
  const config = requireProductionConfiguration();
  const result = await seed(config, catalog, imagePaths);
  console.log('Seed aplicado:', result);
  if (!uploadImages) {
    console.log(
      'Las rutas de imagen siguen apuntando a assets locales. Ejecuta una vez ' +
        'con --upload-images antes de retirar esos assets del paquete Flutter.',
    );
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
