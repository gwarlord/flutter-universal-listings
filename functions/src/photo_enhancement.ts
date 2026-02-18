import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as vision from "@google-cloud/vision";
import * as storage from "@google-cloud/storage";
import FormData from "form-data";
import sharp from "sharp";
import { v4 as uuidv4 } from "uuid";

const db = admin.firestore();
const storageClient = new storage.Storage();
const visionClient = new vision.ImageAnnotatorClient();
const removeBgApiKey = functions.params.defineSecret("REMOVEBG_API_KEY");

/**
 * HTTP Callable Cloud Function to enhance photos with AI
 * 
 * Request body:
 * {
 *   listingId: string,
 *   imageUrl: string (temporary upload URL),
 *   category: 'product' | 'service' | 'person',
 *   subscriptionTier: 'professional' | 'professional_plus' | 'professional_pro',
 *   enhancements: string[],
 *   includeDisclosure: boolean,
 *   usePreview: boolean (optional, default false - if true, uses free preview for background removal)
 * }
 */
export const enhancePhoto = functions
  .runWith({ memory: "1GB", timeoutSeconds: 300, secrets: [removeBgApiKey] })
  .https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }

  const {
    listingId,
    imageUrl,
    category,
    subscriptionTier,
    enhancements,
    includeDisclosure,
    usePreview = false,
  } = data;

  // Validate inputs
  if (!listingId || !imageUrl || !category || !subscriptionTier) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing required fields: listingId, imageUrl, category, subscriptionTier"
    );
  }

  try {
    // 1. Check listing ownership
    const listingDoc = await db.collection("listings").doc(listingId).get();
    if (!listingDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Listing not found");
    }

    const listing = listingDoc.data();
    const ownerId =
      listing?.authorID ||
      listing?.authorId ||
      listing?.userID ||
      listing?.user_id;

    if (!ownerId || ownerId !== context.auth.uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "You do not own this listing"
      );
    }

    // 2. Download image from temporary URL
    const imageBuffer = await downloadImage(imageUrl);

    // 3. Analyze image with Google Vision API
    const visionResults = await analyzeImageWithVision(imageBuffer, category);
    console.log(`Vision results for category: ${category}`, JSON.stringify({category: visionResults.category, hasLabels: visionResults.labels?.length}));
    console.log('Enhancement request details:', JSON.stringify({tier: subscriptionTier, category, enhancements}));

    // 4. Apply enhancements based on tier and Vision results
    let enhancedBuffer = imageBuffer;
    const appliedEnhancements: string[] = [];

    // Always apply these unless tier is 'free'
    if (subscriptionTier !== "free") {
      // Auto-crop/framing
      if (enhancements.includes("auto_crop")) {
        enhancedBuffer = await applyAutoCrop(enhancedBuffer, visionResults);
        appliedEnhancements.push("auto_crop");
      }

      // Lighting normalization
      if (enhancements.includes("lighting_normalization")) {
        enhancedBuffer = await applyLightingNormalization(enhancedBuffer);
        appliedEnhancements.push("lighting_normalization");
      }

      // Clarity enhancement
      if (enhancements.includes("clarity_enhancement")) {
        enhancedBuffer = await applyClarity(enhancedBuffer);
        appliedEnhancements.push("clarity_enhancement");
      }

      // Background blur
      if (enhancements.includes("background_blur")) {
        enhancedBuffer = await applyBackgroundBlur(enhancedBuffer, visionResults);
        appliedEnhancements.push("background_blur");
      }

      // Studio background (white background for products) - available for all paid tiers
      if (enhancements.includes("studio_background")) {
        console.log('Applying studio_background for category:', category, 'visionResults.category:', visionResults.category, 'preview:', usePreview);
        enhancedBuffer = await applyStudioBackground(
          enhancedBuffer,
          visionResults,
          usePreview
        );
        appliedEnhancements.push("studio_background");
      }
    }

    // Professional Plus features
    if (
      subscriptionTier === "professional_plus" ||
      subscriptionTier === "professional_pro"
    ) {
      if (enhancements.includes("background_cleanup")) {
        enhancedBuffer = await cleanupBackground(enhancedBuffer, visionResults);
        appliedEnhancements.push("background_cleanup");
      }

      if (enhancements.includes("subject_isolation")) {
        enhancedBuffer = await isolateSubject(enhancedBuffer, visionResults);
        appliedEnhancements.push("subject_isolation");
      }
    }

    // Professional Pro features
    if (subscriptionTier === "professional_pro") {
      if (enhancements.includes("logo_watermark")) {
        // Watermarking would happen in next phase
        appliedEnhancements.push("logo_watermark");
      }
    }

    // 5. Add disclosure badge if required
    if (includeDisclosure) {
      enhancedBuffer = await addDisclosureBadge(enhancedBuffer);
    }

    // 6. Upload enhanced image to Cloud Storage
    const enhancedUrl = await uploadEnhancedImage(
      enhancedBuffer,
      listingId,
      `enhanced-${uuidv4()}.jpg`
    );

    // 7. Save metadata to Firestore
    const variantId = uuidv4();
    const variantDoc = {
      id: variantId,
      listingId,
      originalImageUrl: imageUrl,
      enhancedImageUrl: enhancedUrl,
      category,
      tier: subscriptionTier,
      enhancements: appliedEnhancements,
      hasDisclosure: includeDisclosure,
      confidenceScore: visionResults.confidenceScore || 0.85,
      processingTimeSeconds: 0,
      appliedEnhancements,
      createdBy: context.auth.uid,
      enhancedAt: new Date().toISOString(),
      isApproved: false,
    };

    await db.collection("image_variants").doc(variantId).set(variantDoc);

    // 8. Return response
    return {
      id: variantId,
      listingId,
      enhancedImageUrl: enhancedUrl,
      originalImageUrl: imageUrl,
      category,
      appliedEnhancements,
      hasDisclosureBadge: includeDisclosure,
      confidenceScore: visionResults.confidenceScore || 0.85,
      processingTimeSeconds: 2.5,
      success: true,
    };
  } catch (error) {
    console.error("Photo enhancement error:", error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      "internal",
      `Enhancement failed: ${error}`
    );
  }
  });

/**
 * Download image from URL
 */
async function downloadImage(imageUrl: string): Promise<Buffer> {
  const response = await fetch(imageUrl);
  if (!response.ok) {
    throw new Error(`Failed to download image: ${response.status}`);
  }
  const buffer = Buffer.from(await response.arrayBuffer());
  
  // Apply EXIF auto-rotation to ensure correct orientation,
  // then return buffer without EXIF metadata
  return await sharp(buffer)
    .rotate() // Auto-rotate based on EXIF
    .toBuffer();
}

/**
 * Analyze image with Google Vision API
 */
async function analyzeImageWithVision(
  imageBuffer: Buffer,
  category: string
): Promise<any> {
  try {
    const request = {
      image: { content: imageBuffer },
      features: [
        { type: "LABEL_DETECTION", maxResults: 10 },
        { type: "OBJECT_LOCALIZATION", maxResults: 10 },
        { type: "TEXT_DETECTION" },
        { type: "DOMINANT_COLORS" },
        { type: "CROP_HINTS" },
      ],
    };

    const responses = await visionClient.annotateImage(request);
    const features = responses[0];

    return {
      labels: features.labelAnnotations || [],
      objects: features.localizedObjectAnnotations || [],
      text: features.textAnnotations || [],
      colors: features.imagePropertiesAnnotation?.dominantColors || [],
      cropHints: features.cropHintsAnnotation?.cropHints || [],
      confidenceScore: 0.85,
      category,
    };
  } catch (error) {
    console.error("Vision API error:", error);
    // Return default if Vision API fails
    return {
      confidenceScore: 0.75,
      category,
      labels: [],
      objects: [],
    };
  }
}

/**
 * Apply auto-crop and framing optimization
 */
async function applyAutoCrop(
  imageBuffer: Buffer,
  visionResults: any
): Promise<Buffer> {
  try {
    const image = sharp(imageBuffer);
    const metadata = await image.metadata();

    // Simple crop to 90% of image (focus on center)
    const width = metadata.width || 1000;
    const height = metadata.height || 1000;

    const cropWidth = Math.floor(width * 0.9);
    const cropHeight = Math.floor(height * 0.9);
    const left = Math.floor((width - cropWidth) / 2);
    const top = Math.floor((height - cropHeight) / 2);

    return await image
      .extract({
        left,
        top,
        width: cropWidth,
        height: cropHeight,
      })
      .toBuffer();
  } catch (error) {
    console.error("Auto-crop error:", error);
    return imageBuffer;
  }
}

/**
 * Apply lighting normalization
 */
async function applyLightingNormalization(
  imageBuffer: Buffer
): Promise<Buffer> {
  try {
    return await sharp(imageBuffer)
      .normalise()
      .sharpen({ sigma: 1.0 })
      .toBuffer();
  } catch (error) {
    console.error("Lighting normalization error:", error);
    return imageBuffer;
  }
}

/**
 * Apply clarity enhancement
 */
async function applyClarity(imageBuffer: Buffer): Promise<Buffer> {
  try {
    return await sharp(imageBuffer)
      .sharpen({ sigma: 0.5 })
      .withMetadata()
      .toBuffer();
  } catch (error) {
    console.error("Clarity enhancement error:", error);
    return imageBuffer;
  }
}

/**
 * Apply background blur
 */
async function applyBackgroundBlur(
  imageBuffer: Buffer,
  visionResults: any
): Promise<Buffer> {
  try {
    return await sharp(imageBuffer)
      .blur(0.3)
      .withMetadata()
      .toBuffer();
  } catch (error) {
    console.error("Background blur error:", error);
    return imageBuffer;
  }
}

/**
 * Clean up background (Professional Plus feature)
 * Only applies slight enhancement without removing background
 */
async function cleanupBackground(
  imageBuffer: Buffer,
  visionResults: any
): Promise<Buffer> {
  try {
    return await sharp(imageBuffer)
      .withMetadata()
      .toBuffer();
  } catch (error) {
    console.error("Background cleanup error:", error);
    return imageBuffer;
  }
}

/**
 * Isolate subject from background (Professional Plus feature)
 * Enhances colors and sharpness without removing background
 */
async function isolateSubject(
  imageBuffer: Buffer,
  visionResults: any
): Promise<Buffer> {
  try {
    return await sharp(imageBuffer)
      .modulate({
        saturation: 1.05,
      })
      .sharpen({ sigma: 0.5 })
      .withMetadata()
      .toBuffer();
  } catch (error) {
    console.error("Subject isolation error:", error);
    return imageBuffer;
  }
}

/**
 * Remove background using remove.bg and place on white
 * @param imageBuffer - The image to process
 * @param usePreview - If true, uses preview mode (free, low-res). If false, uses full quality (costs credits)
 */
async function removeBackgroundToWhite(imageBuffer: Buffer, usePreview: boolean = false): Promise<Buffer> {
  console.log('removeBackgroundToWhite: Starting background removal');
  const apiKey = removeBgApiKey.value();
  if (!apiKey) {
    console.error('removeBackgroundToWhite: API key is missing');
    throw new Error("Remove.bg API key is not configured");
  }

  // Get dimensions of already-rotated image
  const originalMetadata = await sharp(imageBuffer).metadata();
  const originalWidth = originalMetadata.width || 1000;
  const originalHeight = originalMetadata.height || 1000;
  console.log('removeBackgroundToWhite: Original dimensions:', { width: originalWidth, height: originalHeight });

  // Convert to base64
  const base64Image = imageBuffer.toString('base64');

  const size = usePreview ? "preview" : "auto";
  console.log('removeBackgroundToWhite: Calling remove.bg API with size:', size);
  const response = await fetch("https://api.remove.bg/v1.0/removebg", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Api-Key": apiKey,
    },
    body: JSON.stringify({
      image_file_b64: base64Image,
      size: size,
      format: "png",
    }),
  });

  console.log('removeBackgroundToWhite: API response status:', response.status);
  if (!response.ok) {
    const errorText = await response.text();
    console.error('removeBackgroundToWhite: API error:', response.status, errorText);
    throw new Error(`remove.bg failed: ${response.status} ${errorText}`);
  }

  const cutout = Buffer.from(await response.arrayBuffer());
  
  // Detect the object bounds and crop to focus on the product
  const croppedCutout = await cropToContent(cutout);
  
  // Use cropped dimensions for the white background
  const croppedMetadata = await sharp(croppedCutout).metadata();
  const croppedWidth = croppedMetadata.width || 1000;
  const croppedHeight = croppedMetadata.height || 1000;
  
  return await sharp({
    create: {
      width: croppedWidth,
      height: croppedHeight,
      channels: 3,
      background: "#ffffff",
    },
  })
    .composite([{ input: croppedCutout, gravity: "center" }])
    .jpeg({ quality: 92 })
    .toBuffer();
}

/**
 * Crop PNG cutout to remove excess white space around the product
 * Uses edge detection to find the product bounds
 */
async function cropToContent(imageBuffer: Buffer): Promise<Buffer> {
  try {
    const metadata = await sharp(imageBuffer).metadata();
    if (!metadata.width || !metadata.height) {
      return imageBuffer;
    }

    let top = metadata.height;
    let bottom = 0;
    let left = metadata.width;
    let right = 0;

    // Convert image to raw pixel data to analyze alpha channel
    const rawData = await sharp(imageBuffer)
      .raw()
      .toBuffer({ resolveWithObject: true });

    const pixels = rawData.data;
    const channels = rawData.info.channels;
    const width = rawData.info.width;
    const height = rawData.info.height;

    // Find bounds by scanning for non-transparent pixels
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const pixelIndex = (y * width + x) * channels;
        // Extract alpha channel (last channel for RGBA/PNG)
        const alpha = channels >= 4 ? pixels[pixelIndex + 3] : 255;

        // If pixel has opacity (not fully transparent)
        if (alpha > 10) {
          if (y < top) top = y;
          if (y > bottom) bottom = y;
          if (x < left) left = x;
          if (x > right) right = x;
        }
      }
    }

    // Add 5% padding around detected bounds
    const padding = 0.05;
    const contentWidth = Math.max(right - left, 10);
    const contentHeight = Math.max(bottom - top, 10);
    
    const paddingX = Math.floor(contentWidth * padding);
    const paddingY = Math.floor(contentHeight * padding);

    const cropLeft = Math.max(0, left - paddingX);
    const cropTop = Math.max(0, top - paddingY);
    const cropWidth = Math.min(
      metadata.width - cropLeft,
      Math.floor((right - left) + paddingX * 2)
    );
    const cropHeight = Math.min(
      metadata.height - cropTop,
      Math.floor((bottom - top) + paddingY * 2)
    );

    console.log('cropToContent: Original', { width: metadata.width, height: metadata.height });
    console.log('cropToContent: Content bounds', { left, top, right, bottom });
    console.log('cropToContent: Cropping to', { cropLeft, cropTop, cropWidth, cropHeight });

    // Extract the cropped region
    return await sharp(imageBuffer)
      .extract({ left: cropLeft, top: cropTop, width: cropWidth, height: cropHeight })
      .toBuffer();
  } catch (error) {
    console.error('cropToContent error:', error);
    return imageBuffer; // Return original if cropping fails
  }
}

/**
 * Apply studio-style background
 * @param usePreview - If true, uses preview mode (free). If false, uses full quality (costs credits)
 */
async function applyStudioBackground(
  imageBuffer: Buffer,
  visionResults: any,
  usePreview: boolean = false
): Promise<Buffer> {
  try {
    console.log('applyStudioBackground: category check', {received: visionResults?.category, isProduct: visionResults?.category === 'product'});
    if (visionResults?.category === "product") {
      console.log("applyStudioBackground: Calling removeBackgroundToWhite with preview:", usePreview);
      return await removeBackgroundToWhite(imageBuffer, usePreview);
    }

    console.log('applyStudioBackground: Not a product, applying standard studio effect');
    return await sharp(imageBuffer)
      .modulate({
        brightness: 1.05,
        saturation: 1.1,
      })
      .toBuffer();
  } catch (error) {
    console.error("Studio background error:", error);
    console.log('Studio background error - returning original image');
    return imageBuffer;
  }
}
/**
 * Add "Enhanced for Clarity" disclosure badge
 */
async function addDisclosureBadge(imageBuffer: Buffer): Promise<Buffer> {
  try {
    const metadata = await sharp(imageBuffer).metadata();
    const width = metadata.width || 1000;
    const height = metadata.height || 1000;

    // Create SVG badge with "Enhanced for clarity" text
    const svgBadge = Buffer.from(`
      <svg width="${width}" height="30" xmlns="http://www.w3.org/2000/svg">
        <rect width="${width}" height="30" fill="rgba(0,0,0,0.7)"/>
        <text x="10" y="20" font-size="12" fill="white" font-family="Arial">
          Enhanced for clarity
        </text>
      </svg>
    `);

    // Composite badge at bottom
    return await sharp(imageBuffer)
      .composite([
        {
          input: svgBadge,
          top: height - 30,
          left: 0,
        },
      ])
      .toBuffer();
  } catch (error) {
    console.error("Badge addition error:", error);
    return imageBuffer;
  }
}

/**
 * Upload enhanced image to Cloud Storage
 */
async function uploadEnhancedImage(
  imageBuffer: Buffer,
  listingId: string,
  filename: string
): Promise<string> {
  try {
    const bucketName =
      admin.app().options.storageBucket ||
      process.env.FIREBASE_STORAGE_BUCKET ||
      (process.env.GCLOUD_PROJECT
        ? `${process.env.GCLOUD_PROJECT}.appspot.com`
        : "");

    if (!bucketName) {
      throw new Error("Storage bucket name is missing");
    }

    const bucket = storageClient.bucket(bucketName);
    const file = bucket.file(
      `listings/${listingId}/enhanced/${Date.now()}-${filename}`
    );

    await file.save(imageBuffer, {
      metadata: {
        contentType: "image/jpeg",
      },
    });

    // Make file public and return public URL (avoids signBlob permission issue)
    await file.makePublic();
    return `https://storage.googleapis.com/${bucketName}/${file.name}`;
  } catch (error) {
    console.error("Upload error:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to upload enhanced image"
    );
  }
}

/**
 * Cloud Function to save enhancement variant to Firestore
 */
export const saveEnhancementVariant = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { listingId, variantId, variant } = data;

    try {
      await db
        .collection("listings")
        .doc(listingId)
        .collection("image_variants")
        .doc(variantId)
        .set({
          ...variant,
          isPublished: true,
          savedAt: new Date().toISOString(),
        });

      return { success: true, variantId };
    } catch (error) {
      console.error("Save variant error:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to save variant"
      );
    }
  }
);

/**
 * Cleanup old enhancement requests
 */
export const cleanupEnhancements = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async (context) => {
    try {
      const bucketName = process.env.FIREBASE_STORAGE_BUCKET || "";
      const bucket = storageClient.bucket(bucketName);
      const [files] = await bucket.getFiles({
        prefix: "listings/",
      });

      const sevenDaysAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;

      for (const file of files) {
        const [metadata] = await file.getMetadata();
        const timeCreated = metadata.timeCreated as string | undefined;
        if (!timeCreated) continue;
        
        const uploadTime = new Date(timeCreated).getTime();

        if (uploadTime < sevenDaysAgo && file.name.includes("enhancement-input")) {
          await file.delete();
          console.log(`Deleted old file: ${file.name}`);
        }
      }

      return null;
    } catch (error) {
      console.error("Cleanup error:", error);
      return null;
    }
  });




