FROM cimg/aws:2022.06.1

COPY process_s3_files.sh  /home/circleci/project/process_s3_files.sh

CMD ["./process_s3_files.sh"]