# 如未安装包，先运行：
# install.packages(c("readxl", "dplyr", "writexl"))

library(readxl)
library(dplyr)
library(writexl)

# 1. 读取数据
file_path <- "Background_SUVmax.xlsx"
dat <- read_excel(file_path, sheet = 1)

# 部位列名
organ_cols <- c(
  "Kidney", "Liver", "Blood Pool", "Lung", "Bone",
  "Muscle", "Cervical Lymph Node", "Parotid Gland", "Brain"
)

# 如果 readxl 把空格转成了点号，这里自动还原
if (!all(organ_cols %in% names(dat))) {
  names(dat) <- gsub("\\.", " ", names(dat))
}

# 整理数据类型
dat <- dat %>%
  mutate(
    Number = as.numeric(Number),
    Tracer = as.character(Tracer)
  )

# 2. 按 Tracer 分开，并按 Number 配对排序
cd70 <- dat %>%
  filter(Tracer == "CD70") %>%
  select(Number, all_of(organ_cols)) %>%
  arrange(Number)

psma <- dat %>%
  filter(Tracer == "PSMA") %>%
  select(Number, all_of(organ_cols)) %>%
  arrange(Number)

# 检查两组 Number 是否一一对应
stopifnot(identical(cd70$Number, psma$Number))

# 3. 逐部位计算均值、SD、正态性检验、配对检验
res_list <- lapply(organ_cols, function(organ) {
  
  x <- cd70[[organ]]   # CD70
  y <- psma[[organ]]   # PSMA
  
  # 去除缺失值，保证配对
  ok <- complete.cases(x, y)
  x <- x[ok]
  y <- y[ok]
  
  # 配对差值：PSMA - CD70
  d <- y - x
  
  # 先检验差值是否服从正态分布
  sh <- shapiro.test(d)
  
  # 差值正态：Paired t-test；否则：Wilcoxon signed-rank test
  if (sh$p.value >= 0.05) {
    method <- "Paired t-test"
    p_value <- t.test(y, x, paired = TRUE)$p.value
  } else {
    method <- "Wilcoxon signed-rank test"
    p_value <- wilcox.test(y, x, paired = TRUE, exact = FALSE)$p.value
  }
  
  # 均值和标准差
  cd_mean <- mean(x, na.rm = TRUE)
  cd_sd   <- sd(x, na.rm = TRUE)
  
  ps_mean <- mean(y, na.rm = TRUE)
  ps_sd   <- sd(y, na.rm = TRUE)
  
  data.frame(
    部位 = organ,
    `CD70 SUVmax(均值±SD)` = sprintf("%.2f ± %.2f", cd_mean, cd_sd),
    `PSMA SUVmax(均值±SD)` = sprintf("%.2f ± %.2f", ps_mean, ps_sd),
    `差值Shapiro_P` = format.pval(sh$p.value, digits = 4, eps = 0.0001),
    检验方法 = method,
    `P值` = format.pval(p_value, digits = 4, eps = 0.0001),
    check.names = FALSE
  )
})

# 合并结果
res <- bind_rows(res_list)

# 输出到控制台查看
print(res)

# 4. 输出成 Excel 文件
write_xlsx(res, path = "Biodistribution_Supplementary Table S14.xlsx")