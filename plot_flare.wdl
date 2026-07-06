version 1.0

workflow plot_flare {
    input {
        Array[File] global_anc_array
    }

    call plot_global_anc {
        input:
            global_anc_array = global_anc_array
    }

    output {
        File global_anc_plot = plot_global_anc.global_anc_plot
    }
}



task plot_global_anc {
    input {
        Array[File] global_anc_array
    }

    command <<<
        R << RSCRIPT
        library(tidyverse)
        library(RColorBrewer)

        combine_chrs <- function(flare_files) {
            tmp <- read_tsv(flare_files[1])
            samples <- as.character(tmp[["SAMPLE"]])
            fracs <- tmp[,-1]
            for (c in seq_along(flare_files)[-1]) {
                tmp <- read_tsv(flare_files[c])
                stopifnot(all(tmp[["SAMPLE"]] == samples))
                fracs <- fracs + tmp[,-1]
            }
            fracs <- fracs / rowSums(fracs)
            flr <- bind_cols(sample_id=samples, fracs)
            return(flr)
        }

        flare_files <- readLines('~{write_lines(global_anc_array)}')
        dat <- combine_chrs(flare_files)

        K <- ncol(dat) - 1
        group_names <- names(dat)[-1]
        cluster_order <- dat %>% select(-sample_id) %>% colSums() %>% sort(decreasing = TRUE) %>% names()
        dat <- dat %>% arrange(across(all_of(cluster_order)))
        dat <- mutate(dat, n=row_number())
        dat <- dat %>% pivot_longer(cols = all_of(cluster_order), names_to='Cluster', values_to='K')
        dat[['Cluster']] <- factor(dat[['Cluster']], levels = cluster_order)
        d2 <- brewer.pal(8, 'Dark2'); s2 <- brewer.pal(8, 'Set2')
        colormap <- setNames(c(d2, s2)[1:K], group_names)
        ggbar <- ggplot(dat, aes(x=n, y=K, fill=Cluster, color=Cluster)) + 
            geom_bar(stat='identity') + 
            scale_fill_manual(values=colormap, breaks=rev(names(colormap))) + 
            scale_color_manual(values=colormap, breaks=rev(names(colormap))) + 
            theme_classic() + 
            theme(axis.line=element_blank(), axis.ticks.x=element_blank(), axis.text.x=element_blank(), axis.title.x=element_blank(), axis.ticks.y=element_blank(), axis.text.y=element_blank(), axis.title.y=element_blank(), panel.spacing=unit(0, 'in'))
        ggsave('global_anc_plot.png', plot=ggbar, width=11, height=4)
        RSCRIPT
    >>>

    output {
        File global_anc_plot = "global_anc_plot.png"
    }

	runtime {
		docker: "rocker/tidyverse:4"
	}
}
