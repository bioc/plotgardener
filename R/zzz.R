.onLoad <- function(libname, pkgname) {

    ## Define params object  -----------------------------

    ## Initialize documented params function names
    x <- c("assembly", "gene", "geneBuffer")

    ## Set argument inputs for function definition
    allArgs1 <- paste(paste0(x, "=NULL"), collapse = ",")
    allArgs2 <- paste0(paste(x, "=", x), collapse = ",")

    ## Change specific argument defaults
    allArgs1 <- gsub("assembly=NULL", 'assembly="hg38"', allArgs1)
    allArgs1 <- paste0(allArgs1, ",...")

    ## Pass all arguments into function definition
    pgParams <- parse(text = c(sprintf("

    pgParams <- function(%s) {

    ## Construct object
    object <- structure(.Data = list(%s), class = 'pgParams')
    object[names(list(...))] <- list(...)

    ## Feature: setting region parameters by gene name & assembly -------------

    if (!is.null(gene)){

        ## Parse assembly
        assembly <- parseAssembly(assembly = assembly)

        if (is(assembly$TxDb, 'TxDb')){
            txdbChecks <- TRUE
        } else {
            if (!requireNamespace(assembly$TxDb, quietly = TRUE)){
                txdbChecks <- FALSE
                warning('`', assembly$TxDb, '` not available. Please install',
                ' to define genomic region based on a gene.', call. = FALSE)
            } else {
                txdbChecks <- TRUE
            }
            
        }
        
        ## Custom orgDb
        if (is(assembly$OrgDb, 'OrgDb')){
            orgdbChecks <- TRUE
        } else {
            if (!requireNamespace(assembly$OrgDb, quietly = TRUE)){
                orgdbChecks <- FALSE
                warning('`', assembly$OrgDb, '` not available. Please install',
                ' to define genomic region based ona  gene.', call. = FALSE)
            } else {
                orgdbChecks <- TRUE
            }
        }
        
        if (txdbChecks == TRUE & orgdbChecks == TRUE){

            if (is(assembly$TxDb, 'TxDb')){
                tx_db <- assembly$TxDb
            } else {
                tx_db <- eval(parse(text = paste0(as.name(assembly$TxDb),
                                            '::',
                                            as.name(assembly$TxDb))))
            }
            
            if (is(assembly$OrgDb, 'OrgDb')){
                org_db <- assembly$OrgDb
            } else {
                org_db <- eval(parse(text = paste0(as.name(assembly$OrgDb),
                                        '::',
                                        as.name(assembly$OrgDb))))
            }

        ## Filter TxDb for standard chromosomes
        tx_db <- keepStandardChromosomes(tx_db, pruning.mode = 'coarse')
        
        chromSizes <- GenomeInfoDb::seqlengths(tx_db)
        idCol <- assembly$gene.id.column
        displayCol <- assembly$display.column

        ## convert input gene name to geneID
        geneID <- tryCatch(expr = {
            suppressMessages(AnnotationDbi::select(org_db, keys = gene,
            columns = c(idCol), keytype = displayCol))

        }, error = function(e) stop('Gene', shQuote(gene),
        'does not exist in assembly.', call. = FALSE))

        geneData <- suppressMessages(AnnotationDbi::select(tx_db,
        keys = geneID[[idCol]], columns = AnnotationDbi::columns(tx_db),
        keytype = 'GENEID'))
    
        ## Temporarily convert geneData to GRanges
        geneData_GRanges <- makeGRangesFromDataFrame(geneData, 
        keep.extra.columns = TRUE, seqnames.field = 'TXCHROM', 
        start.field = 'TXSTART', end.field = 'TXEND')
    
        ## Filter non-standard chromosomes from geneData GRanges
        geneData_GRanges <- keepStandardChromosomes(geneData_GRanges, 
                                                    pruning.mode = 'coarse')
        
        ## Convert back to original format
        geneData <- as.data.frame(geneData_GRanges)
        geneData <- subset(geneData, select = -c(width, strand))
        colnames(geneData)[colnames(geneData) == 'seqnames'] <- 'TXCHROM'
        colnames(geneData)[colnames(geneData) == 'start'] <- 'TXSTART'
        colnames(geneData)[colnames(geneData) == 'end'] <- 'TXEND'

        ## Check that user has not supplied both gene and chrom/start/end
        chrom <- object$chrom
        chromstart <- object$chromstart
        chromend <- object$chromend
        if(any(!is.null(c(chrom, chromstart, chromend)))) {
            stop('Cannot use \\'gene\\' in combination with \\'chrom\\',
            \\'chromstart\\', or \\'chromend\\'', call. = FALSE)
        }

        ## Get info about gene region
        minGeneStart <- min(geneData$TXSTART)
        maxGeneEnd <- max(geneData$TXEND)

        ## Set default gene buffer (window = 2X gene length)
        ## Define buffer
        if (is.null(geneBuffer)) geneBuffer <- (maxGeneEnd - minGeneStart) / 2

        if (length(geneBuffer) == 1) geneBuffer <- rep(geneBuffer, 2)

        ## Assign values to params object (with buffer)
        object$chrom      <- unique(geneData$TXCHROM)
        object$chromstart <- minGeneStart - geneBuffer[1]
        object$chromend   <- maxGeneEnd  + geneBuffer[2]
        object$geneBuffer <- geneBuffer

        ## Extract chromSizes length
        chrLength <- chromSizes[[object$chrom]]

        ## Check that starts and ends are within chromSizes
        if (object$chromstart < 1) {
            object$chromstart <- 1
            message('geneBuffer range is less than start. Start has been
            adjusted', call. = FALSE)
        }

        if (object$chromend > chrLength) {
            object$chromend   <- chrLength
            message('geneBuffer range is greater than end. End has been
            adjusted', call. = FALSE)
        }

        }

    }

    ## Filter out null values for pretty printing
    object <- structure(Filter(Negate(is.null), object), class = 'pgParams')

    return(object)

    }
                                        ", allArgs1, allArgs2)))

    ## Assign function in environment
    assign("pgParams", eval(pgParams), rlang::ns_env(pkgname))
}
