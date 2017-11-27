#!/bin/sh
#
# Usage: qsub -q cpu.q run_qiime2.sh [time]]
#       

# -- our name ---
#$ -N QIIME2-UDD
#$ -S /bin/sh
# Make sure that the .e and .o file arrive in the
# working directory
#$ -cwd
#Merge the standard out and standard error to one file
#$ -j y
/bin/echo Here I am: `hostname`. Sleeping now at: `date`
/bin/echo Running on host: `hostname`.
/bin/echo In directory: `pwd`
/bin/echo Starting on: `date`
#$ -m be
#$ -M marcelorojas@udd.cl

#Para activar QIIME2 y los requerimientos del sistema
source /hpcudd/home/mrojas/.bash_profile
source activate qiime2-2017.10

#Para Importar los datos de las muestras
qiime tools import \
  --type 'SampleData[PairedEndSequencesWithQuality]' \
  --input-path manifest_files.csv \
  --output-path paired-end-demux.qza \
  --source-format PairedEndFastqManifestPhred33

#Para visualizar el resultado del archivo generado en el paso anterior (cargar archivo .qzv en https://view.qiime2.org)
qiime demux summarize --i-data paired-end-demux.qza --o-visualization paired-end-demux.qzv

#Corriendo dada2 para generar secuencias representativas, eliminar primeras 5 pares de bases, no truncar largo y usara todos los cores disponibles del nodo
qiime dada2 denoise-paired \
  --i-demultiplexed-seqs paired-end-demux.qza \
  --p-trim-left-f 5 \
  --p-trim-left-r 5 \
  --p-trunc-len-f 0 \
  --p-trunc-len-r 0 \
  --o-representative-sequences rep-seqs-dada2.qza \
  --o-table table-dada2.qza \
  --p-n-threads 0

qiime feature-table summarize \
  --i-table table-dada2.qza \
  --o-visualization table-dada2.qzv \
  --m-sample-metadata-file metadata.txt

qiime alignment mafft \
  --i-sequences rep-seqs-dada2.qza \
  --o-alignment aligned-rep-seqs-dada2.qza \
  --p-n-threads 28

qiime alignment mask \
  --i-alignment aligned-rep-seqs-dada2.qza \
  --o-masked-alignment masked-aligned-rep-seqs-dada2.qza

qiime phylogeny fasttree \
  --i-alignment masked-aligned-rep-seqs-dada2.qza \
  --o-tree unrooted-tree.qza

qiime phylogeny midpoint-root \
  --i-tree unrooted-tree.qza \
  --o-rooted-tree rooted-tree.qza

qiime diversity core-metrics-phylogenetic \
  --i-phylogeny rooted-tree.qza \
  --i-table table-dada2.qza \
  --p-sampling-depth 7500 \
  --m-metadata-file metadata.txt \
  --output-dir core-metrics-results

qiime diversity alpha-group-significance \
  --i-alpha-diversity core-metrics-results/faith_pd_vector.qza \
  --m-metadata-file metadata.txt \
  --o-visualization core-metrics-results/faith-pd-group-significance.qzv

qiime diversity alpha-group-significance \
  --i-alpha-diversity core-metrics-results/evenness_vector.qza \
  --m-metadata-file metadata.txt \
  --o-visualization core-metrics-results/evenness-group-significance.qzv

qiime diversity beta-group-significance \
  --i-distance-matrix core-metrics-results/unweighted_unifrac_distance_matrix.qza \
  --m-metadata-file metadata.txt \
  --m-metadata-category baseline_mdro \
  --o-visualization core-metrics-results/unweighted-unifrac-baseline_mdro-significance.qzv \
  --p-pairwise

qiime diversity beta-group-significance \
  --i-distance-matrix core-metrics-results/unweighted_unifrac_distance_matrix.qza \
  --m-metadata-file metadata.txt \
  --m-metadata-category AB \
  --o-visualization core-metrics-results/unweighted-unifrac-AB-group-significance.qzv \
  --p-pairwise

qiime diversity alpha-rarefaction \
  --i-table table-dada2.qza \
  --i-phylogeny rooted-tree.qza \
  --p-max-depth 7500 \
  --o-visualization alpha-rarefaction-7500.qzv

################################################################
# To training reference set
qiime tools import \
  --type 'FeatureData[Sequence]' \
  --input-path /hpcudd/home/mrojas/my_data/Project_1_RafaelAraos/qiime2/training_classifier/gg_13_5_otus/rep_set/97_otus.fasta \
  --output-path gg-13_5-97_otus.qza

qiime tools import \
  --type 'FeatureData[Taxonomy]' \
  --source-format HeaderlessTSVTaxonomyFormat \
  --input-path /hpcudd/home/mrojas/my_data/Project_1_RafaelAraos/qiime2/training_classifier/gg_13_5_otus/taxonomy/97_otu_taxonomy.txt \
  --output-path ref-taxonomy.qza

qiime feature-classifier extract-reads \
  --i-sequences gg-13_5-97_otus.qza \
  --p-f-primer GTGCCAGCMGCCGCGGTAA \
  --p-r-primer GGACTACHVGGGTWTCTAAT \
  --p-trunc-len 250 \
  --o-reads ref-seqs.qza

qiime feature-classifier fit-classifier-naive-bayes \
  --i-reference-reads ref-seqs.qza \
  --i-reference-taxonomy ref-taxonomy.qza \
  --o-classifier classifier.qza
################################################################


qiime feature-classifier classify-sklearn \
  --i-classifier gg-13-8-99-515-806-nb-classifier.qza \
  --i-reads rep-seqs-dada2.qza \
  --o-classification taxonomy.qza

qiime metadata tabulate \
  --m-input-file taxonomy.qza \
  --o-visualization taxonomy.qzv

qiime taxa barplot \
  --i-table table-dada2.qza \
  --i-taxonomy taxonomy.qza \
  --m-metadata-file metadata.txt \
  --o-visualization taxa-bar-plots.qzv

/bin/echo Ending on: `date`


