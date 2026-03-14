package storage

import (
	"context"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"io"
	"strconv"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

func BackBlazeS3Endpoint(region string) string {
	return fmt.Sprintf("https://s3.%s.backblazeb2.com", region)
}

var _ BlobStorage = (*S3Storage)(nil)

type S3Storage struct {
	client *s3.Client
	bucket string
}

func NewS3Storage(region string, endpoint string, key string, secret string, session string, bucket string) *S3Storage {
	client := s3.New(s3.Options{
		Region:       region,
		BaseEndpoint: &endpoint,
		Credentials: credentials.NewStaticCredentialsProvider(
			key,
			secret,
			session,
		),
	})

	return &S3Storage{
		client: client,
		bucket: bucket,
	}
}

func (s *S3Storage) GetBlobs(ctx context.Context) (map[string]BlobInfo, error) {
	input := &s3.ListObjectsV2Input{
		Bucket: aws.String(s.bucket),
		Prefix: aws.String("blobs/"),
	}

	blobs := make(map[string]BlobInfo)

	for {
		result, err := s.client.ListObjectsV2(context.TODO(), input)
		if err != nil {
			return nil, err
		}

		input.ContinuationToken = result.NextContinuationToken

		for _, blob := range result.Contents {
			etag, err := strconv.Unquote(*blob.ETag)
			if err != nil {
				return nil, err
			}

			blobs[*blob.Key] = BlobInfo{
				Digest:       "md5:" + etag,
				LastModified: *blob.LastModified,
				Size:         *blob.Size,
			}
		}

		if result.NextContinuationToken == nil {
			break
		}
	}

	return blobs, nil
}

func (s *S3Storage) PutBlob(ctx context.Context, key string, r ReadAtSeeker, digest string, size int64) error {
	algorithm, digest, ok := strings.Cut(digest, ":")
	if !ok {
		return fmt.Errorf("invalid digest")
	}

	if algorithm != "md5" {
		return fmt.Errorf("invalid digest")
	}

	md5sum, err := hex.DecodeString(digest)
	if err != nil {
		return err
	}

	_, err = s.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:        aws.String(s.bucket),
		Key:           aws.String(key),
		Body:          r,
		ContentMD5:    aws.String(base64.StdEncoding.EncodeToString(md5sum)),
		ContentLength: aws.Int64(size),
	})
	if err != nil {
		return err
	}

	return nil
}

func (s *S3Storage) GetBlob(ctx context.Context, key string) (io.ReadCloser, string, error) {
	blob, err := s.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return nil, "", err
	}

	etag, err := strconv.Unquote(*blob.ETag)
	if err != nil {
		blob.Body.Close()
		return nil, "", err
	}

	return blob.Body, "md5:" + etag, nil
}
